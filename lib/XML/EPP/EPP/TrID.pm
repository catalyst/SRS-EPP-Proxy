
package SRS::EPP::Message::EPP::TrID;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'clTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	predicate => "has_clTRID",
	;

has 'svTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	;

method elements() {
	( ( $self->has_clTRID ? ("clTRID") : () ),
	  "svTRID" );
}

method attributes() {
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::trIDType"
	=> as __PACKAGE__;

1;
