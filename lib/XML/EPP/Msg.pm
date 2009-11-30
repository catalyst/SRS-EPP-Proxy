
package XML::EPP::Msg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

has_element 'content' =>
	is => "rw",
	isa => "PRANG::XMLSchema::normalizedString",
	xml_nodeName => "",
	;

has_attr 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	default => "en",  # imperialists!!
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::msgType"
	=> as __PACKAGE__;

1;
