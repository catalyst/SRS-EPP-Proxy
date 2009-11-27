
package SRS::EPP::Message::EPP::Poll;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

# based on epp-1.0.xsd:greetingType
use Moose::Util::TypeConstraints;

enum "${SCHEMA_PKG}::pollOpType" =>
	qw(ack req);

has 'op' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::pollOpType",
	required => 1,
	;

has 'msgID' =>
	is => "rw",
	isa => "PRANG::XMLSchema::token",
	predicate => "has_msgID",
	;

method elements() {
}

method attributes() {
	("op",
	 ($self->has_msgID ? ("msgID") : ()),
	 );
}

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::pollType"
	=> as __PACKAGE__;

1;
