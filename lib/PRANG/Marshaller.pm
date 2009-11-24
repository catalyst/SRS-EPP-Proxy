
package PRANG::Marshaller;

use Moose;
use MooseX::Method::Signatures;

use XML::LibXML 1.70;

has 'class' =>
	isa => "Moose::Meta::Class",
	is => "ro",
	required => 1,
	;

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

method to_xml( Object $item ) {
}

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
	my $rv = $self->marshall_in_element($rootNode, $xsi);
}

method marshall_in_element( XML::LibXML::Node $node, HashRef $xsi ) returns PRANG::Graph::Node {

	my $attributes = $self->attributes;
	my @elements = @{ $self->elements };

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
			push @init_args, $attr->name, $attr->value;
		}
		else {
			# fail.
			die "invalid attribute '".$attr->name."' on "
				$node->nodeName." (input line "
					.$node->line_number.")";
		}
	}

	# now process elements
	my @childNodes = $node->nonBlankChildNodes;
	my ($expected, $expect_type, $expect_many, $expect_one);
	my ($expect_bool, $expect_str, $expect_obj, $expect_union);
	my $shift_expected = sub {
		$expected = shift @$expected;
		if ( $expected->has_xml_required ) {
			$expect_one = $expected->xml_required;
		}
		elsif ( $expected->has_predicate ) {
			$expect_one = 0;
		}
		else {
			$expect_one = 1;
		}
		$expect_type = $expected->type_constraint
			or die "no type constraint on element "
				.$self->class->name."::".$expected->name;
		if ( $expect_type->is_a_type_of("ArrayRef") ) {
			$expect_type->isa("Moose::Meta::TypeConstraint::Parameterized")
				or die "ArrayRef, but not Parameterized on "
					.$self->class->name."::".$expected->name;
			$expect_many = 1;
			$expect_type = $expect_type->type_parameter;
		}
		else {
			$expect_many = 0;
		}
		undef($_) for ($expect_bool, $expect_str, $expect_obj, $expect_union);
		if ( $expect_type->is_a_type_of("Bool") ) {
			$expect_bool = 1;
		}
		if ( $expect_type->is_a_type_of("Str") or
			     $expect_type->is_a_type_of("Int") ) {
			$expect_str = 1;
		}
		if ( $expect_type->is_a_type_of("Object") ) {
			$expect_obj = 1;
		}
		my $types = $expect_obj + $expect_str + $expect_bool;
		if ( $types == 0 ) {
			die "don't know what to expect with $expect_type "
				.($self->class->name."::".$expected->name);
		}
		elsif ( $types > 1 or $expect) {
			$expect_union 
		}
	};
	my $t_c = $expected->type_constraint;
	my $got_count;
	while ( @childNodes ) {
		my $found = shift @childNodes;
		my $elementName = $found->localname;
		if ( $expected->type_constraint->is_subtype_of("ArrayRef") ) {
			
		}
	}
}

1;
