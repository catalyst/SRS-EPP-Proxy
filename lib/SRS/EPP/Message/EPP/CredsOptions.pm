
package SRS::EPP::Message::EPP::CredsOptions;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

has 'version' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::versionType",
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

1;
