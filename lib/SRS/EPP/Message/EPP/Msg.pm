
package SRS::EPP::Message::EPP::Msg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'content' =>
	is => "rw",
	isa => "PRANG::XMLSchema::normalizedString",
	;

has 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	default => sub { "en" },  # imperialists!!
	;


method elements() {
	qw(content);
}

method attributes() {
	qw(lang);
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::msgType"
	=> as __PACKAGE__;

1;
