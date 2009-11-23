
package SRS::EPP::Message::EPP::SvcMenu;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'version' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::versionType]",
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
	isa => "${SCHEMA_PKG}::ExtURI",
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

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::svcMenuType"
	=> as __PACKAGE__;

1;
