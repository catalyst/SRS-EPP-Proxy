
package SRS::EPP::Message::EPPCom::Reason;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPPCom";

has 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	predicate => "has_lang",
	;

has 'content' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::reasonBaseType",
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

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::reasonType"
	=> as __PACKAGE__;

1;
