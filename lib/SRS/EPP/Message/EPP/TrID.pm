
package SRS::EPP::Message::EPP::TrID;

use Moose;
use MooseX::Method::Signatures;
with 'SRS::EPP::Message::EPP::Node';

has 'clTRID' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::trIDStringType",
	predicate => "has_clTRID",
	;

has 'svTRID' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPP::trIDStringType",
	;

method elements() {
	( ( $self->has_clTRID ? ("clTRID") : () ),
	  "svTRID" );
}

method attributes() {
}

1;
