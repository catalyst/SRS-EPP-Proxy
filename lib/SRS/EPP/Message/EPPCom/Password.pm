
package SRS::EPP::Message::EPPCom::Password;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPPCom::Node';

has 'roid' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPPCom::roidType",
	predicate => "has_roid",
	;

has 'content' =>
	is => "rw",
	isa => "PRANG::XMLSchema::normalizedString",
	;

method elements() {
	# it's a simpleContent, I think that means the data is a
	# textNode; let's say that a single-item list signifies that.
	([ $self->content ],
	);
}
method attributes() {
	( ( $self->has_roid
		? ([ undef, "roid", $self->roid ]) : () ) );
}

1;
