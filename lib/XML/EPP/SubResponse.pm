
package XML::EPP::SubResponse;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
use XML::EPP::Plugin;

our $SCHEMA_PKG = "XML::EPP";

has 'response_type' =>
	is => "rw",
	isa => "Str",
	;

has_element "payload" =>
	is => "rw",
	isa => "XML::EPP::Plugin",
	xmlns => "*",
	xml_nodeName => "*",
	xml_nodeName_attr => "response_type",
	;

with "${SCHEMA_PKG}::Node";

# no special type for this - this is 'epp:extAnyType'

1;
