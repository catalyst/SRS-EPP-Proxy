
package SRS::EPP::Message::EPP::ExtURI;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

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

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::extURIType"
	=> as __PACKAGE__;

1;
