
package SRS::EPP::Message::EPP::Transfer;

# based on epp-1.0.xsd:greetingType

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'object_name' =>
	is => "rw",
	isa => "Str",
	;

has 'object' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::Object",
	;

enum "${SCHEMA_PKG}::transferOpType" =>
	qw(approve cancel query reject request);

has 'op' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::transferOpType",
	required => 1,
	;

method elements() {
	([ undef, $self->object_name, $self->object ],
	 );
}

method attributes() {
	("op",
	);
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::transferType"
	=> as __PACKAGE__;

1;
