
package SRS::EPP::Message::EPP::Greeting;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

# based on epp-1.0.xsd:greetingType
use Moose::Util::TypeConstraints;

our $PKG = "SRS::EPP::Message::EPP::Greeting";
our $SCHEMA_PKG = $SRS::EPP::Message::EPP::PKG;

has 'svID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::sIDType",
	;

has 'svDate' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	;

has 'svcMenu' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::SvcMenu",
	;

has 'dcp' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::DCP",
	;

method attributes() {

}

method elements() {
	# something like this should be possible too as a shorthand
	qw( svID svDate svcMenu dcp );
}

1;
