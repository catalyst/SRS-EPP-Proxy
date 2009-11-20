
package SRS::EPP::Message::EPP::SvcMenu;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

has 'version' =>
	is => "rw",
	isa => "ArrayRef[SRS::EPP::Message::EPP::versionType]",
	;

has 'lang' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::language]",
	;

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
	( ( map { [ undef, "version", $_ ] } @{ $self->version || [] } ),
	  ( map { [ undef, "lang", $_ ] } @{ $self->lang || [] } ),
	  ( map { [ undef, "objURI", $_ ] } @{ $self->objURI || [] } ),
	  ( $self->has_svcExtension
		    ? ([ undef, "svcExtension", $self->svcExtension ]) : () ),
	 )
}

method attributes() {
}

1;
