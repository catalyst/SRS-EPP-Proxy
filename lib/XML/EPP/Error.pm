package XML::EPP::Error;

# I've called this class 'error' - extErrValueType is a stupid name.

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

use XML::EPP::Msg;
use PRANG::XMLSchema::Whatever;

# anything which takes a 'whatever' should by definition be able to
# have any other node put in which isn't a Whatever object; in fact
# that is what is intended with this support, to be able to return
# invalid fragments in an error response.
subtype "${SCHEMA_PKG}::errValueType"
	=> as "PRANG::XMLSchema::Whatever|PRANG::Graph::Class";

has_element 'value' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::errValueType",
	;

has_element 'reason' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgType",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::extErrValueType"
	=> as __PACKAGE__;

1;
