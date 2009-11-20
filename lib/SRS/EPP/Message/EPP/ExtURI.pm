
package SRS::EPP::Message::EPP::ExtURI;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

has 'extURI' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::anyURI]",
	;

method elements() {
	# new convention: if the 'object' is a string, it's a
	# simpleContent
	( ( map { [ undef, "extURI", $_ ] } @{ $self->extURI || [] } ),
	 )
}

method attributes() {
}

1;
