
package XML::EPP;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

use constant XSI_XMLNS => "http://www.w3.org/2001/XMLSchema-instance";

use XML::EPP::Common;

our $PKG;
BEGIN{ $PKG = "XML::EPP" };

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
	subtype "${PKG}::sIDType"
		=> as "PRANG::XMLSchema::normalizedString"
		=> where {
			length($_) >= 3 and length($_) <= 64;
		};

	subtype "${PKG}::versionType"
		=> as "PRANG::XMLSchema::token"
		=> where {
			m{^[1-9]+\.[0-9]+$} and $_ eq "1.0";
		};

	subtype "${PKG}::trIDStringType"
		=> as "PRANG::XMLSchema::token"
		=> where {
			length($_) >= 3 and length($_) <= 64;
		};
}

# rule 2.  ALL elements get converted to MessageNode types, with
# classes preferably named after the name of the element
use XML::EPP::Hello;

# however, as 'extURIType' is used in multiple places, with different
# element names, it gets a name based on its type.
use XML::EPP::ExtURI;
use XML::EPP::SvcMenu;
use XML::EPP::DCP;
use XML::EPP::Greeting;
use XML::EPP::CredsOptions;
use XML::EPP::RequestedSvcs;
use XML::EPP::Login;
use XML::EPP::Poll;
use XML::EPP::SubCommand;
use XML::EPP::Transfer;

# first rule: map complexTypes to classes.  Where types are only used
# in one place, the name of the class is the name of the *element* in
# which it is used.
use XML::EPP::Command;
use XML::EPP::TrID;
use XML::EPP::Extension;
use XML::EPP::Msg;
use XML::EPP::Result;
use XML::EPP::Response;

#=====================================================================
#  'epp' node definition
#=====================================================================
use PRANG::Graph;

# Now we have all of the type constraints from the XMLSchema
# definition defined, we can implement the 'epp' node.

# there is a 'choice' - this item has no name in the schema to use, so
# we call it 'choice0'
subtype "${PKG}::choice0" =>
	=> as join("|", map { "${PKG}::$_" }
			   qw(greetingType Hello commandType
			      responseType extAnyType) );

# but we map it to the object property 'message'; again this comes
# under 'schema customisation'
has_element 'message' =>
	is => "rw",
	isa => "${PKG}::choice0",
	xml_nodeName => {
		"greeting" => "${PKG}::Greeting",
		"command" => "${PKG}::Command",
		"response" => "${PKG}::Response",
		"extension" => "${PKG}::Extension",
		"hello" => "${PKG}::Hello",
	       },
	handles => ["is_response"],
	;

method root_element { "epp" }

# this class implements a Message format - ie, a root of a schema - as
# well as a node - the documentRoot
with "PRANG::Graph", "XML::EPP::Node";

method is_command() {
	$self->message->is_command;
}

method is_response() {
	!$self->message->is_command;
}

1;
