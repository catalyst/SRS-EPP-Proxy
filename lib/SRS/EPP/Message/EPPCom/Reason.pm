
package SRS::EPP::Message::EPPCom::Reason;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPPCom::Node';

has 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	predicate => "has_lang",
	;

has 'content' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPPCom::reasonBaseType",
	;

method elements() {
	# it's a simpleContent, I think that means the data is a
	# textNode; let's say that a single-item list signifies that.
	([ $self->content ],
	);
}
method attributes() {
	( ( $self->has_lang
		? ([ undef, "lang", $self->lang ]) : () ) );
}

1;
