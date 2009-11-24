
package PRANG::Graph::Meta::Element;

use Moose;
extends 'Moose::Meta::Attribute';

has 'xmlns' =>
	is => "rw",
	isa => "Str",
	predicate => "has_xmlns",
	;

has 'xml_nodeName' =>
	is => "rw",
	isa => "Str|CodeRef|HashRef|ScalarRef",
	predicate => "has_nodeName",
	;

has 'xml_required' =>
	is => "rw",
	isa => "Bool",
	predicate => "has_xml_required",
	;

has '+isa' =>
	required => 1,
	;

sub BUILD {
	
}

package Moose::Meta::Attribute::Custom::PRANG::Element;
sub register_implementation {
	"PRANGE::Graph::Meta::Element";
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
      xml_nodeName_attr => "message_names",
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

