
package SRS::EPP::Message::EPP::Msg;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

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

1;
