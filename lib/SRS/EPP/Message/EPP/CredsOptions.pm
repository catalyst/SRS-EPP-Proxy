
package SRS::EPP::Message::EPP::CredsOptions;

use Moose;
use MooseX::Method::Signatures;

our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'version' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::versionType",
	;

has 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	;

method elements() {
	qw(version lang);
}

method attributes() {
}

with "${SCHEMA_PKG}::Node";

use Moose::Util::TypeConstraints;

subtype "${SCHEMA_PKG}::credsOptionsType" =>
	as __PACKAGE__;

1;
