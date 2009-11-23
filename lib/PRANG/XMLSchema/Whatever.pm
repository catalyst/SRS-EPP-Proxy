
# Here is the offending definition for this:

#  <complexType name="mixedMsgType" mixed="true">
#    <sequence>
#      <any processContents="skip"
#       minOccurs="0" maxOccurs="unbounded"/>
#    </sequence>
#    <attribute name="lang" type="language"
#     default="en"/>
#  </complexType>

# The mixed="true" part means that we can have character data (the
# validation of which cannot be specified AFAIK).  See
#  http://www.w3.org/TR/xmlschema11-1/#Complex_Type_Definition_details
#
# Then we get an unbounded "any", with processContents="skip"; this
# means that everything under this point - including XML namespace
# definitions, etc - should be completely ignored.  The only
# requirement is that the contents are valid XML.  See
#  http://www.w3.org/TR/xmlschema11-1/#Wildcard_details

# XXX - should really make roles for these different conditions:

#    PRANG::XMLSchema::Wildcard::Skip;
#
#      'skip' specifically means that no validation is required; if
#      the input document specifies a schema etc, that information is
#      to be ignored.  In this instance, we may as well be returning
#      the raw LibXML nodes.

#    PRANG::XMLSchema::Wildcard::Lax;
#
#      processContents="lax" means to validate if the appropriate xsi:
#      etc attributes are present; otherwise to treat as if it were
#      'skip'

#    PRANG::XMLSchema::Wildcard::Strict;

#      Actually this one may not be required; just specifying the
#      'Node' role should be enough.  As 'Node' is not a concrete
#      type, the rest of the namespace and validation mechanism should
#      be able to check that the nodes are valid.

# In addition to these different classifications of the <any>
# wildcard, the enclosing complexType may specify mixed="true";
# so, potentially there are two more roles;

#    PRANG::XMLSchema::Any;              (cannot mix data and elements)
#    PRANG::XMLSchema::Any::Mixed;       (can mix them)

# however dealing with all of these different conditions is currently
# probably premature; the schema we have only contains 'strict' (which
# as noted above potentially needs no explicit support other than
# correct XMLNS / XSI implementation) and 'Mixed' + 'Skip'; so I'll
# make this "Whatever" class to represent this most lax of lax
# specifications.

package PRANG::XMLSchema::Whatever;

use Moose;
use MooseX::Method::Signatures;

has 'contents' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::Whatever|Str]",
	;

has 'names' =>
	is => "rw",
	isa => "ArrayRef[Maybe[Str]]",
	;

has '_attributes' =>
	is => "rw",
	isa => "HashRef[Str]",
	;

# here's a new meta-type method; specify a function which accepts
# _all_ of the attributes given.  This would also be required for the
# <anyAttribute> wildcard
method all_attributes(HashRef $attribs) {
	$self->_attributes($attribs);
}

method attributes() {
	$self->_attributes;
}

method xmlns() {
	# ... meep?
	"";
}

# we don't need to specify 'attributes'; so long as the generator is
# happy to find a hashref returned and DTRT.

method elements() {
	my @rv;
	return unless $self->contents;
	for (my $i = 0; defined $self->contents->[$i]; $i++ ) {
		my $item = $self->contents->[$i];
		if ( ref $item ) {
			push @rv, [ undef, $self->names->[$i], $item ];
		}
		else {
			push @rv, [ $item ];
		}
	}
}

with 'SRS::EPP::MessageNode'; # XXX - should pull these into PRANG

1;
