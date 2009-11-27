
package PRANG::Marshaller;

use Moose;
use MooseX::Method::Signatures;

use XML::LibXML 1.70;

has 'class' =>
	isa => "Moose::Meta::Class",
	is => "ro",
	required => 1,
	;

our %marshallers;  # could use MooseX::NaturalKey?
method get($inv: Str $class) {
	if ( ref $inv ) {
		$inv = ref $inv;
	}
	$marshallers{$class} ||= do {
		$inv->new( class => $class->meta );
	}
}

has 'attributes' =>
	isa => "HashRef[HashRef[PRANG::Graph::Meta::Attr]]",
	is => "ro",
	lazy => 1,
	required => 1,
	default => sub {
		my $self = shift;
		my @attr = grep { $_->isa("PRANG::Graph::Meta::Attr") }
			$self->class->get_all_attributes;
		my $default_xmlns = eval { $self->class->name->xmlns };
		my %attr_ns;
		for my $attr ( @attr ) {
			my $xmlns = $attr->has_xmlns ?
				$attr->xmlns : $default_xmlns;
			my $xml_name = $attr->has_xml_name ?
				$attr->xml_name : $attr->name;
			$attr_ns{$xmlns}{$xml_name} = $attr;
		}
		\%attr_ns;
	};

has 'elements' =>
	isa => "ArrayRef[PRANG::Graph::Meta::Element]",
	is => "ro",
	lazy => 1,
	required => 1,
	default => sub {
		my $self = shift;
		my @elements = grep {
			$_->isa("PRANG::Graph::Meta::Element")
		} $self->class->get_all_attributes;
		my @e_c = map { $_->associated_class->name } @elements;
		my %e_c_does;
		for my $parent ( @e_c ) {
			for my $child ( @e_c ) {
				if ( $parent eq $child ) {
					$e_c_does{$parent}{$child} = 0;
				}
				else {
					$e_c_does{$parent}{$child} =
						( $child->does($parent)
							  ? 1 : -1 );
				}
			}
		}
		[ map { $elements[$_] } sort {
			$e_c_does{$e_c[$a]}{$e_c[$b]} or
				($e_c[$a]->insertion_order
					 <=> $e_c[$b]->insertion_order)
			} 0..$#elements ];
	};

has 'acceptor' =>
	is => "rw",
	isa => "PRANG::Graph::Node",
	lazy => 1,
	required => 1,
	default => sub {
		$_[0]->build_acceptor;
	},
	;

method parse( Str $xml ) {

	my $dom = XML::LibXML->load_xml(
		string => $xml,
	       );

	my $rootNode = $dom->documentElement;
	my $rootNodeNS = $rootNode->namespaceURI;
	my $expected_ns = $self->class->xmlns;

	if ( $rootNodeNS and $expected_ns ) {
		if ( $rootNodeNS ne $expected_ns ) {
			die "Namespace mismatch: expected '$expected_ns', found '$rootNodeNS'";
		}
	}
	my $xsi = {};
	my $rv = $self->marshall_in_element(
		$rootNode,
		$xsi,
		"/".$rootName->nodeName,
	       );
	$rv;
}

method marshall_in_element( XML::LibXML::Node $node, HashRef $xsi, Str $xpath ) {

	my $attributes = $self->attributes;
	my @node_attr = grep { $_->isa("XML::LibXML::Attr") }
		$node->attributes;
	my @ns_attr = $node->getNamespaces;

	if ( @ns_attr ) {
		$xsi = { %$xsi,
			 map { ($_->declaredPrefix||"") => $_->declaredURI }
				 @ns_attr };
	}

	my @init_args;

	# process attributes
	for my $attr ( @node_attr ) {
		my $prefix = $attr->prefix || "";
		if ( !exists $xsi->{$prefix} ) {
			die "unknown xmlns prefix '$prefix' on ".
				$node->nodeName." (input line "
					.$node->line_number.")";
		}
		my $xmlns = $xsi->{$prefix};
		my $meta_att = $attributes->{$xmlns}{"*"} ||
			$attributes->{$xmlns}{$attr->localname};

		if ( $meta_att ) {
			# sweet, it's ok
			my $att_name = $meta_att->name;
			push @init_args, $att_name, $attr->value;
		}
		else {
			# fail.
			die "invalid attribute '".$attr->name."' on "
				$node->nodeName." (input line "
					.$node->line_number.")";
		}
	};

	# now process elements
	my @childNodes = $node->nonBlankChildNodes;
	if ( !$self->has_acceptor ) {
		$self->acceptor($self->build_acceptor);
	}

	my $acceptor = $self->acceptor;
	my $context = PRANG::Graph::Context->new(
		base => $self,
		xpath => $xpath,
		xsi => $xsi,
		prefix => ($node->prefix||""),
	       );

	my (%init_args, %init_arg_names);
	while ( my $input_node = shift @childNodes ) {
		if ( my ($key, $value, $name) =
			     $acceptor->accept($input_node, $context) ) {
			my $meta_att;
			if ( exists $init_args{$key} ) {
				if ( !ref $init_args{$key} or
					     ref $init_args{$key} ne "ARRAY" ) {
					$init_args{$key} = [$init_args{$key}];
					$init_arg_names{$key} = [$init_arg_names{$key}]
						if exists $init_arg_names{$key};
				}
				push @{$init_args{$key}}, $value;
				if (defined $name) {
					my $idx = $#{$init_args{$key}};
					$init_arg_names{$key}[$idx] = $name;
				}
			}
			else {
				$init_args{$key} = $value;
				$init_arg_names{$key} = $name
					if defined $name;
			}
		}
	}


	if ( !$acceptor->complete($context) ) {
		my (@what) = $acceptor->expected($context);
		$context->exception(
			"Node incomplete; expecting: @what",
			$node,
			);
	}
	# now, we have to take all the values we just got and
	# collapse them to init args
	for my $element ( @{ $self->elements } ) {
		my $key = $element->name;
		next unless exists $init_args{$key};
		if ( $element->has_xml_max and $element->xml_max == 1 ) {
			# expect item
			if ( $element->has_xml_nodeName_attr and
				     exists $init_arg_names{$key} ) {
				push @init_args, $element->xml_nodeName_attr =>
					delete $init_arg_names{$key};
			}
			if (ref $init_args{$key} and
				    $init_args{$key} eq "ARRAY" ) {
				$context->exception(
"internal error: we ended up multiple values set for '$key' attribute",
					$node);
			}
			push @init_args, $key => delete $init_args{$key}
		}
		else {
			# expect list
			if ( !ref $init_args{$key} or
				     $init_args{$key} ne "ARRAY" ) {
				$init_args{$key} = [$init_args{$key}];
				$init_arg_names{$key} = [$init_arg_names{$key}]
					if exists $init_arg_names{$key};
			}
			if ( $element->has_xml_nodeName_attr and
				     exists $init_arg_names{$key} ) {
				push @init_args,
					$element->xml_nodeName_attr =>
						delete $init_arg_names{$key}
			}
			push @init_args, $key => delete $init_args{$key};
		}
	}
	if (keys %init_args) {
		$context->exception(
		"internal error: init args left over (@{[ keys %init_args ]})",
			$node,
		       );
	}
	my $value = eval { $self->class->name->new( @init_args ) };
	if ( !$value ) {
		die "Validation error during processing of $xpath ("
			.$self->class->name." constructor returned "
				."error: $@)";
	}
	else {
		return $value;
	}
}

method build_acceptor( Moose::Meta::Class $class ) {
	my @nodes = map { $_->graph_node } @{ $self->elements };
	if ( @nodes > 1 ) {
		PRANG::Graph::Seq->new(
			members => \@nodes,
		       );
	}
	elsif ( @nodes ) {
		$nodes[0];
	}
	else {
		PRANG::Graph::Empty->new;
	}
}

method xml_version { "1.0" };
method encoding { "UTF-8" };

# nothing to see here ... move along please ...
our $zok;
our %zok_seen;
our @zok_themes = (qw( tmnt octothorpe quantum pokemon hhgg pasta
		       phonetic sins punctuation discworld lotr
		       loremipsum batman tld garbage python pooh
		       norse_mythology ));
our $zok_theme;

our $gen_prefix;
method generate_prefix( Str $xmlns ) returns Str {
	if ( $zok or eval { require Acme::MetaSyntactic; 1 } ) {
		my $name;
		do {
			$zok ||= do {
				%zok_seen=();
				if ( defined $zok_theme ) {
					$zok_theme++;
					if ( $zok_theme > $#zok_themes ) {
						$zok_theme = 0;
					}
				}
				else {
					$zok_theme = int(time / 86400)
						% scalar(@zok_themes);
				}
				Acme::MetaSyntactic->new(
					$zok_themes[$zok_theme],
				       );
			};
			do {
				$name = $zok->name;
				if ($zok_seen{$name}++) {
					undef($zok);
					undef($name);
					goto next_theme;
				};
			} while ( length($name) > 10 or
					  $name !~ m{^[A-Za-z]\w+$} );
			next_theme:
		}
			until ($name);
		return $name;
	}
	else {
		# revert to a more boring prefix :)
		$gen_prefix ||= "a";
		$prefix++;
	}
}

method to_xml_doc( PRANG::Graph $item ) returns XML::LibXML::Document {
	my $xmlns = $item->xmlns;
	my $xsi = { "" => $xmlns, "()" => sub {
			    my $thing = shift;
			    my $xmlns = shift;
			    if ( $thing->can("preferred_prefix") ) {
				    $thing->preferred_prefix($xmlns);
			    }
			    elsif ( $item->can("xmlns_prefix") ) {
				    $item->xmlns_prefix($xmlns);
			    }
			    else {
				    $self->generate_prefix($xmlns);
			    }
		    } };
	%zok_seen=();
	undef($gen_prefix);
	my $doc = XML::LibXML::Document->new(
		$self->xml_version, $self->encoding,
	       );
	$doc->setDocumentElement( $root );
	my $root = $self->to_libxml( $item, $doc, $xsi );
	$doc;
}

method to_xml( Object $item ) returns Str {
	$self->to_xml_doc($item)->toString;
}

method to_libxml( Object $item, XML::LibXML::Element $node, HashRef $xsi ) returns XML::LibXML::Element {

	my %rxsi = ( reverse %$xsi );
	my $attributes = $self->attributes;
	my $XSI = $xsi;
	my $node_prefix = $node->prefix;
	#my $doc = $node->getOwner;
	my $get_prefix = sub {
		my $xmlns = shift;
		if ( !exists $rxsi{$xmlns} ) {
			my $prefix = $xsi->{"()"}->($item, $xmlns);
			if ( $XSI == $xsi ) {
				$XSI = { %$xsi };
			}
			$XSI->{$prefix} = $xmlns;
			$rxsi{$xmlns} = $prefix;
			$node->setAttribute("xmlns:".$prefix, $xmlns);
		}
		$rxsi{$xmlns};
	};
	# do attributes
	while ( my ($xmlns, $att) = each %$attributes ) {
		my $prefix = $get_prefix->{$xmlns};
		if ( $prefix ne "" ) {
			$prefix .= ":";
		}
		while ( my ($attName, $meta_att) = each %$att ) {
			my $is_optional;
			my $obj_att_name = $meta_att->name;
			if ( $meta_att->has_xml_required ) {
				$is_optional = !$meta_att->xml_required;
			}
			elsif ( $meta_att->has_predicate ) {
				# it's optional
				$is_optional = 1;
			}
			# we /could/ use $meta_att->get_value($item)
			# here, but I consider that to break
			# encapsulation
			my $value = $item->$obj_att_name;
			if ( !defined $value ) {
				die "could not serialize $item; slot "
					.$meta_att->name." empty"
						unless $is_optional;
			}
			else {
				$node->setAttribute(
					$prefix.$attName,
					$value,
				       );
			}
		}
	}

	# now child elements - let the graph do the work.
	my $graph = $self->acceptor;
	$graph->output($item, $node, $xsi);

	$node;
}

1;

