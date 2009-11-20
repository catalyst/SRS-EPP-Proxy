
package SRS::EPP::Message::EPP::RequestedSvcs;

# FIXME: make a ::ServiceList role; this is very similar to SvcMenu

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

has 'objURI' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::anyURI]",
	;

has 'svcExtension' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::ExtURI",
	predicate => "has_svcExtension",
	;

method elements() {
	# new convention: if the 'object' is a string, it's a
	# simpleContent
	( ( map { [ undef, "objURI", $_ ] } @{ $self->objURI || [] } ),
	  ( $self->has_svcExtension
		    ? ([ undef, "svcExtension", $self->svcExtension ]) : () ),
	 )
}

method attributes() {
}

1;
