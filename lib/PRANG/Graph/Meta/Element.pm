
package PRANG::Graph::Meta::Element;

use Moose;
extends 'Moose::Meta::Attribute';
use MooseX::Method::Signatures;

has 'xmlns' =>
	is => "rw",
	isa => "Str",
	predicate => "has_xmlns",
	;

has 'xml_nodeName' =>
	is => "rw",
	isa => "Str|HashRef",
	predicate => "has_nodeName",
	;

has 'xml_nodeName_attr' =>
	is => "rw",
	isa => "Str",
	predicate => "has_nodeName_attr",
	;

has 'xml_required' =>
	is => "rw",
	isa => "Bool",
	predicate => "has_xml_required",
	;

has 'xml_min' =>
	is => "rw",
	isa => "Int",
	predicate => "has_xml_min",
	;

has 'xml_max' =>
	is => "rw",
	isa => "Int",
	predicate => "has_xml_max",
	;

has '+isa' =>
	required => 1,
	;

has 'graph_node' =>
	is => "rw",
	isa => "PRANG::Graph::Node",
	lazy => 1,
	required => 1,
	default => sub {
		my $self = shift;
		$self->build_graph_node;
	},
	;

use constant HIGHER_ORDER_TYPE =>
	"Moose::Meta::TypeConstraint::Parameterized";

method build_graph_node() {
	my ($expect_one, $expect_many);

	if ( $self->has_xml_required ) {
		$expect_one = $self->xml_required;
	}
	elsif ( $self->has_predicate ) {
		$expect_one = 0;
	}
	else {
		$expect_one = 1;
	}

	my $t_c = $self->type_constraint;

	# check to see whether ArrayRef was specified
	if ( $t_c->is_a_type_ok("ArrayRef") ) {
		my $is_paramd;
		until ( $t_c->equals("ArrayRef") ) {
			if ( $t_c->isa(HIGHER_ORDER_TYPE) ) {
				$is_paramd = 1;
				last;
			}
			else {
				$t_c = $t_c->parent;
			}
		}
		if (not $is_paramd) {
			die "ArrayRef, but not Parameterized on "
				.$self->name;
		}
		$expect_many = 1;

		$t_c = $t_c->type_parameter;
	}

	# ok.  now let's walk the type constraint tree, and look for
	# types
	my ($expect_bool, $expect_simple, @expect_type, @expect_role);

	my @st = $t_c;
	my %t_c;
	while ( my $x = shift @st ) {
		$t_c{$x} = $x;
		if ( $x->isa("Moose::Meta::TypeConstraint::Class") ) {
			push @expect_type, $x->class;
		}
		elsif ( $x->isa("Moose::Meta::TypeConstraint::Union") ) {
			push @st, @{ $x->parents };
		}
		elsif ( $x->isa("Moose::Meta::TypeConstraint") ) {
			if ( $x->equals("Bool") ) {
				$expect_bool = 1;
			}
			elsif ( $x->equals("Value") ) {
				$expect_simple = 1;
			}
			else {
				push @st, $x->parent;
			}
		}
		elsif ( $x->isa("Moose::Meta::TypeConstraint::Enum") ) {
			$expect_simple = 1;
		}
		elsif ( $x->isa("Moose::Meta::TypeConstraint::Role") ) {
			# likely to be a wildcard.
			push @expect_role, $x->role;
		}
		else {
			die "Sorry, I don't know how to map a ".ref($x).
				" in attribute ".$self->name;
		}
	}

	my $node;
	my $nodeName = $self->has_xml_nodeName ?
		$self->xml_nodeName : $self->name;

	if ( $expect_bool + $expect_simple + @expect_type > 1
		     or @expect_role ) {
		# multiple or ambiguous types are specified; we *need*
		# to know
		if ( ! ref $nodeName ) {
			die "type union specified, but no nodename map"
				." given for attr ".$self->name;
		}
		while ( my ($nodeName, $type) = each %$nodeName ) {
			if ( not exists $t_c{$type} ) {
				die "nodeName to type map specifies "
." $nodeName => '$type', but $type is not an acceptable type for attr "
	.$self->name;
			}
		}
	}
	if ( !ref $nodeName ) {
		my $expected = $expect_bool ? "Bool" :
			$expect_simple ? "Str" : $expect_type[0];
		$nodeName = { $nodeName => $expected };
	}

	my @expect;
	for my $class ( @expect_type ) {
		my @xmlns;
		# XXX - this isn't quite right... it should be
		# $class->xmlns;
		if ( $self->has_xmlns ) {
			push @xmlns, (xmlns => $self->xmlns);
		}
		my (@names) = grep { $nodeName->{$_} eq $class }
			keys %$nodeName;

		if ( !@names ) {
			die "type '$class' specified as allowed, but "
				."which node names indicate that type?"
					." for attr ".$self->name;
		}

		for my $name ( @names ) {
			push @expect, PRANG::Graph::Element->new(
				@xmlns,
				attName => $self->name,
				attIsArray => $expect_many,
				nodeClass => $class,
				nodeName => $name,
			       );
			delete $nodeName->{$name};
		}
	}

	if ( $expect_bool ) {
		my (@names) = grep {
			!$t_c{$nodeName->{$_}}->is_a_type_of("Object")
		} keys %$nodeName;

		# 'Bool' elements are a shorthand for the element
		# 'maybe' being there.
		for my $name ( @names ) {
			push @expect, PRANG::Graph::Element->new(
				attName => $self->name,
				attIsArray => $expect_many,
				nodeName => $name,
			       );
			delete $nodeName->{$name};
		}
	}
	if ( $expect_simple ) {
		my (@names) = grep {
			!$t_c{$nodeName->{$_}}->is_a_type_of("Object")
		} keys %$nodeName;
		for my $name ( @names ) {
			# 'Str', 'Int', etc element attributes: this
			# means an XML data type: <attr>value</attr>
			if ( !length($name) ) {
				# this is for 'mixed' data
				push @expect, PRANG::Graph::Text->new(
					attName => $self->name,
					attIsArray => $expect_many,
				       );
			}
			else {
				# regular XML data style
				push @expect, PRANG::Graph::Element->new(
					attName => $self->name,
					attIsArray => $expect_many,
					nodeClass => "Str",
					nodeName => $name,
					contents => PRANG::Graph::Text->new,
				       );
			}
			delete $nodeName->{$name};
		}
	}

	if ( @expect > 1 ) {
		$node = PRANG::Graph::Choice->new(
			choices => \@expect,
		       );
	}
	elsif ( $expect_bool ) {
		$expect_one = 0;
	}

	# deal with limits
	if ( !$expect_one or $expect_many) {
		my @min_max;
		if ( $expect_one and !$self->has_xml_min ) {
			$self->xml_min(1);
		}
		if ( $self->has_xml_min ) {
			push @min_max, min => $self->xml_min;
		}
		if ( !$expect_many and !$self->has_xml_max ) {
			$self->xml_max(1);
		}
		if ( $self->has_xml_max ) {
			push @min_max, max => $self->xml_max;
		}
		$node = PRANG::Graph::Quantity->new(
			@min_max,
			child => $node,
		       );
	}

	return $node;
}

package Moose::Meta::Attribute::Custom::PRANG::Element;
sub register_implementation {
	"PRANG::Graph::Meta::Element";
};

1;

=head1 NAME

PRANG::Graph::Meta::Element - metaclass for XML elements

=head1 SYNOPSIS

 use PRANG::Graph;

 has_element 'somechild' =>
    is => "rw",
    isa => $str_subtype,
    predicate => "has_somechild",
    ;

=head1 DESCRIPTION

When defining a class, you mark attributes which correspond to XML
element children.  To do this in a way that the PRANG::Marshaller can
use when marshalling to XML and back, make the attributes have this
metaclass.

You could do this in principle with:

 has 'somechild' =>
    metaclass => 'PRANG::Element',
    ...

But PRANG::Graph exports a convenient shorthand for you to use.

If you like, you can also set the 'xmlns' and 'xml_nodeName' attribute
property, to override the default behaviour, which is to assume that
the XML element name matches the Moose attribute name, and that the
XML namespace of the element is that of the I<value> (ie,
C<$object-E<gt>somechild-E<gt>xmlns>.

The B<order> of declaring element attributes is important.  They
implicitly define a "sequence".  To specify a "choice", you must use a
union sub-type - see below.

The B<predicate> property of the attribute is also important.  If you
do not define C<predicate>, then the attribute is considered
I<required>.  This can be overridden by specifying C<xml_required> (it
must be defined to be effective).

The B<isa> property (B<type constraint>) you set via 'isa' is
I<required>.  The behaviour for major types is described below.  The
module knows about sub-typing, and so if you specify a sub-type of one
of these types, then the behaviour will be as for the type on this
list.

B<note:> this man page is I<B<U<OUT OF DATE>>> in subtle ways.  Use
the source, Luke - until it is corrected.

=over 4

=item B<Bool  sub-type>

If the attribute is a Bool sub-type (er, or just "Bool", then the
element will marshall to the empty element if true, or no element if
false.  The requirement that C<predicate> be defined is relaxed for
C<Bool> sub-types.

ie, C<Bool> will serialise to:

   <object>
     <somechild />
   </object>

For true and

   <object>
   </object>

For false.

=item B<Scalar sub-type>

If it is a Scalar subtype (eg, an enum, a Str or an Int), then the
value of the Moose attribute is marshalled to the value of the element
as a TextNode; eg

  <somechild>somevalue</somechild>

=item B<Object sub-type>

If the attribute is an Object subtype (ie, a Class), then the element
is serialised according to the definition of the Class defined.

eg, with

   class CD {
       has_element 'author' => qw( is rw isa Person );
       has_attr 'name' => qw( is rw isa Str );
   }
   class Person {
       has_attr 'group' => qw( is rw isa Bool );
       has_attr 'name' => qw( is rw isa Str );
       has_element 'deceased' => qw( is rw isa Bool );
   }

Then the object;

  CD->new(
    name => "2Pacalypse Now",
    author => Person->new(
       group => 0,
       name => "Tupac Shakur",
       deceased => 1)
  );

Would serialise to (assuming that there is a L<PRANG::Graph> document
type with C<cd> as a root element):

  <cd name="2Pacalypse Now">
    <author group="0" name="Tupac Shakur>
      <deceased />
    </author>
  </cd>

=item B<Union types>

Union types are special; they indicate that any one of the types
indicated may be expected next.  By default, the name of the element
is still the name of the Moose attribute, and if the case is that a
particular element may just be repeated any number of times, this is
find.

However, this can be inconvenient in the typical case where the
alternation is between a set of elements which are allowed in the
particular context, each corresponding to a particular Moose type.
Another one is the case of mixed XML, where there may be text, then
XML fragments, more text, more XML, etc.

There are two relevant questions to answer.  When marshalling OUT, we
want to know what element name to use for the attribute in the slot.
When marshalling IN, we need to know what element names are allowable,
and potentially which sub-type to expect for a particular element
name.

The following scenarios arise;

=over

=item B<1:1 mapping from Type to Element name>

This is often the case for message containers that allow any number of
a collection of classes inside.  For this case, a map must be provided
to the C<xml_nodeName> function, which allows marshalling in and out
to proceed.

  has_element 'message' =>
      is => "rw",
      isa => "my::unionType",
      xml_nodeName => {
          "nodename" => "TypeA",
          "somenode" => "TypeB",
      };

It is an error if types are repeated in the map.  The empty string can
be used as a node name for text nodes, otherwise they are not allowed.

=item B<more element names than types>

This can happen for two reasons: one is that the schema that this
element definition comes from is re-using types.  Another is that you
are just accepting XML without validation (eg, XMLSchema's
C<processContents="skip"> property).  In this case, there needs to be
another attribute which records the names of the node.

  has_element 'message' =>
      is => "rw",
      isa => "my::unionType",
      xml_nodeName => {
          "nodename" => "TypeA",
          "somenode" => "TypeB",
          "someother" => "TypeB",
      },
      xml_nodeName_attr => "message_name",
      ;

If any node name is allowed, then you can simply pass in C<*> as an
C<xml_nodeName> value.

=back

=item B<ArrayRef sub-type>

An C<ArrayRef> sub-type indicates that the element may occur multiple
times at this point.  Currently, bounds are not specified directly -
use a sub-type of C<ArrayRef> which specifies a type constraint to
achieve this.

If C<xml_nodeName> is specified, it is applied to I<items> in the
array ref.

Higher-order types are supported; in fact, to not specify the type of
the elements of the array is a big no-no.

When you have "choice" nodes in your XML graph, and these choices are
named, then you can specify a sub-type which is that list of types.

eg

  subtype "My::XML::Language::choice0"
     => as join("|", map { "My::XML::Language::$_" }
                  qw( CD Store Person ) );

  has_element 'things' =>
     is => "rw",
     isa => "ArrayRef[My::XML::Language::choice0]",
     xml_nodeName => sub { lc(ref($_)) },
     ;

This would allow the enclosing class to have a 'things' property,
which contains all of the elements at that point, which can be C<cd>,
C<store> or C<person> elements.

=cut

