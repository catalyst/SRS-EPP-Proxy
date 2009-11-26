
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

method to_xml( Object $item ) {
}


1;

__END__

		my $nodeType = $input_node->nodeType;
		my $node_xpath = $xpath."/".$input_node->nodeName;
		next if $nodeType == XML_COMMENT_NODE;
		my $ok_node;
		if ( $is_text->($nodeType) ) {
			$ok_node = $acceptor->textnode_ok($pos, $found);
		}
		elsif ( $nodeType == XML_ELEMENT_NODE ) {
			my $node_prefix = $input_node->prefix;
			my $xmlns;
			if ( $node->prefix ne $node_prefix ) {
				$xmlns = $xsi->{$node_prefix};
			}
			$ok_node = $acceptor->element_ok(
				$xmlns, $input_node->localname,
				$pos, $found,
			       );
		}
		if ( !$is_ok and $acceptor->skip_ok($pos, $found) ) {
			$pos++;
			$found = 0;
			unshift @childNodes, $input_node;
			next;
		}
		if ( $is_ok ) {
			my ($attName, $attClass) = $ok_node->att_what($pos);
			my $full_att_name = $self->class->name."->".$attName;
			my $pos_inc = $acceptor->pos_inc($pos);
			if ( $pos_inc ) {
				$pos++;
				$found = 0;
			}
			else {
				$found++;
			}
			if ( $attClass eq "Str" or $attClass eq "Bool" ) {
				# must be XML data
				$if ($input_node->hasAttributes) {
					die "Superfluous attributes on "
			."XML data node: $node_xpath ($full_att_name)";
				}
			}
			if ( $attClass eq "Bool" ) {
				if ( $input_node->hasChildNodes ) {
					die "Superfluous child nodes on "
			."XML data node: $node_xpath ($full_att_name)";
				}
				push @init_args, $attName => 1;
			}
			elsif ( $attClass eq "Str" ) {
				my @childNodes =
					$input_node->nonBlankChildNodes;
				if ( @childNodes > 1 ) {
					# we could maybe merge CDATA nodes...
					die "Too many child nodes for "
				."XML data: $node_xpath ($full_att_name)";
				}
				if ( !@childNodes ) {
					push @init_args, $attName => "";
				}
				elsif ( $is_text->($childNodes[0]->nodeType)
				       ) {
					push @init_args, $attName =>
						$childNodes[0]->data;
				}
				else {
					die "Wrong child node type for "
."XML data; expected TextNode or CDATA Section: $node_xpath ($full_att_name)";
				}
			}
			else {
				# recurse!
				my $subm = (ref $self)->get( $attClass );
				my $value = $subm->marshall_in_element(
					$input_node,
					$xsi,
					($xpath."/".$input_node->nodeName),
				       );
				push @init_args, $attname => $value;
			}
		}
		else {
			# we've run out of options.  die.
		}
