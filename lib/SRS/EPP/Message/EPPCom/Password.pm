
package SRS::EPP::Message::EPPCom::Password;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPPCom";

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

with 'SRS::EPP::Message::EPPCom::Node';

subtype "${SCHEMA_PKG}::pwAuthInfoType"
	=> as __PACKAGE__;

1;
