package XML::EPP::Error;

# I've called this class 'error' - extErrValueType is a stupid name.

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

use XML::EPP::Msg;
use PRANG::XMLSchema::Whatever;

# XML::LibXML::Element|PRANG::Graph::Class means that the object
# within may be parsed (a PRANG::Graph::Class object) or unparsed
# (XML::LibXML)
subtype "${SCHEMA_PKG}::errValueType"
	=> as "XML::LibXML::Element|PRANG::Graph::Class";

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
