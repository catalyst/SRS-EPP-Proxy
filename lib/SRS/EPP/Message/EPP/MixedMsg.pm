
package SRS::EPP::Message::EPP::MixedMsg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

extends 'PRANG::XMLSchema::Whatever';

has 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	default => sub { "en" },  # imperialists!!
	;

method all_attributes(HashRef $attribs) {
	$self->lang(delete $attribs->{lang});
	$self->SUPER::all_attributes($attribs);
}

subtype "${SCHEMA_PKG}::mixedMsgType"
	=> as (__PACKAGE__."|SRS::EPP::MessageNode");

1;
