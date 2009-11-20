
package SRS::EPP::Message::EPP::Poll;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

# based on epp-1.0.xsd:greetingType
use Moose::Util::TypeConstraints;

has 'op' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::pollOpType",
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
	 ($self->has_msgID ? ("msgID") : (),
	 );
}

1;
