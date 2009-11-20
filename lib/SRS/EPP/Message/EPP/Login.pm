
package SRS::EPP::Message::EPP::Login;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

# based on epp-1.0.xsd:greetingType
use Moose::Util::TypeConstraints;

our $PKG = "SRS::EPP::Message::EPP::Login";
our $SCHEMA_PKG = $SRS::EPP::Message::EPP::PKG;

use SRS::EPP::Message::EPPCom;

has 'clID' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPPCom::clIDType",
	;

has 'pw' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::Password",
	;

has 'newPW' =>
	is => "rw",
	predicate => "has_newPW",
	isa => "${SCHEMA_PKG}::Password",
	;

has 'options' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::credsOptionsType",
	;

has 'svcs' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::loginSvcType",
	;

method elements() {
	(qw(clID pw),
	 ( $self->has_newPW ? ("newPW") : () ),
	 qw(options svcs),
	);
}

method attributes() {
}

1;
