
package SRS::EPP::Message::EPP;

use Moose;
use MooseX::Method::Signatures;

# this class implements a Message format - ie, a root of a schema - as
# well as a node - the documentRoot
with "SRS::EPP::Message", "SRS::EPP::Message::EPP::Node";

use constant XSI_XMLNS => "http://www.w3.org/2001/XMLSchema-instance";

use SRS::EPP::Message::EPPCom;

use Moose::Util::TypeConstraints;

our $PKG = "SRS::EPP::Message::EPP";

#=====================================================================
#  epp-1.0.xsd mapping to types
#=====================================================================
# as this module describes the message format (ie, epp-1.0.xsd), it
# contains all of the types from that namespace, as well as the
# definition of the node.

# in principle, this should be generated programmatically; however
# this is a manual conversion based on a set of principles which are
# outlined in the comments.

# rule 1. simpleTypes become subtypes of basic types.  We need an
# XMLSchema type library for the 'built-in' XMLSchema types, I'll put
# them for the time being in:
use PRANG::XMLSchema::Types;

BEGIN {
	subtype "${PKG}::sIDType" =>
		as => "PRANG::XMLSchema::normalizedString",
			where {
				length($_) >= 3 and length($_) <= 64;
			};

	subtype "${PKG}::versionType" =>
		as => "PRANG::XMLSchema::token",
			where {
				m{^[1-9]+\.[0-9]+$} and $_ eq "1.0";
			};

	subtype "${PKG}::trIDStringType" =>
		as => "PRANG::XMLSchema::token",
			where {
				length($_) >= 3 and length($_) <= 64;
			};
}

# rule 2.  ALL elements get converted to MessageNode types, with
# classes preferably named after the name of the element
use SRS::EPP::Message::EPP::Hello;

# however, as 'extURIType' is used in multiple places, with different
# element names, it gets a name based on its type.
use SRS::EPP::Message::EPP::ExtURI;
use SRS::EPP::Message::EPP::SvcMenu;
use SRS::EPP::Message::EPP::DCP;
use SRS::EPP::Message::EPP::Greeting;
use SRS::EPP::Message::EPP::CredsOptions;
use SRS::EPP::Message::EPP::RequestedSvcs;
use SRS::EPP::Message::EPP::Login;
use SRS::EPP::Message::EPP::Poll;
use SRS::EPP::Message::EPP::Object;
use SRS::EPP::Message::EPP::Transfer;

# first rule: map complexTypes to classes.  Where types are only used
# in one place, the name of the class is the name of the *element* in
# which it is used.
use SRS::EPP::Message::EPP::Command;
use SRS::EPP::Message::EPP::TrID;
use SRS::EPP::Message::EPP::Extension;
use SRS::EPP::Message::EPP::Msg;
use SRS::EPP::Message::EPP::Result;
use SRS::EPP::Message::EPP::Response;

#=====================================================================
#  'epp' node definition
#=====================================================================

# Now we have all of the type constraints from the XMLSchema
# definition defined, we can implement the 'epp' node.

# there is a 'choice' - this item has no name in the schema to use, so
# we call it 'choice0'
subtype "${PKG}::choice0" =>
	as => join("|", map { "${PKG}::$_" }
			   qw(greetingType Hello commandType
			      responseType extAnyType) );

# but we map it to the object property 'message'; again this comes
# under 'schema customisation'
has 'message' =>
	is => "rw",
	isa => "${PKG}::choice0",
	;

# to build XML, we need to return the attributes in the node.  This
# would normally be automatically generated, although the root node is
# somewhat special as it contains XML namespaces.
method attributes() {
	( [ undef, "xmlns", __PACKAGE__->xmlns ],
	  [ undef, "xmlns:xsi", XSI_XMLNS ],
	  [ XSI_XMLNS, "schemaLocation", __PACKAGE__->xmlns."\n"
		    .'epp-1.0.xsd' ],
	 );
}

# we need to be able to go from the type of the 'message' element to
# the node name to use; this should be generated.
method choice0_element( SRS::EPP::Message::EPP::choice0 $message )
	returns (Str) {
	if ( $message->isa("${PKG}::greetingType") ) {
		"greeting";
	}
	elsif ( $message->isa("${PKG}::commandType") ) {
		"command"
	}
	elsif ( $message->isa("${PKG}::responseType") ) {
		"response"
	}
	elsif ( $message->isa("${PKG}::extAnyType") ) {
		"extension"
	}
	elsif ( $message->isa("${PKG}::Hello") ) {
		"hello";
	}
}

# returns the child elements, in order.
#  [ namespace URI, element name, object ]
method elements() {
	( [ undef, $self->choice0_element($self->message), $self->message ],
	 );
}

1;
