
package SRS::EPP::Message::EPP::Transfer;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

# based on epp-1.0.xsd:greetingType
use Moose::Util::TypeConstraints;

has 'object_name' =>
	is => "rw",
	isa => "Str",
	;

has 'object' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::Object",
	;

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

1;
