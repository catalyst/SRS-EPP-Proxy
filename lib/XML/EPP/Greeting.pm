
package XML::EPP::Greeting;

# based on epp-1.0.xsd:greetingType

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $PKG = "XML::EPP::Greeting";
our $SCHEMA_PKG = "XML::EPP";

has_element 'svID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::sIDType",
	;

has_element 'svDate' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	;

has_element 'svcMenu' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::SvcMenu",
	;

has_element 'dcp' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::DCP",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::greetingType"
	=> as __PACKAGE__;

sub is_command { 1 }

1;
