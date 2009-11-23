
package SRS::EPP::Message::EPP::MsgQ;

use SRS::EPP::Message::EPP::MixedMsg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

has 'qDate' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	predicate => "has_qDate",
	;

has 'msg' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::mixedMsgType",
	predicate => "has_msg",
	;

has 'count' =>
	is => "rw",
	isa => "PRANG::XMLSchema::unsignedLong",
	;

has 'id' =>
	is => "rw",
	isa => "SRS::EPP::Message::EPPCom::minTokenType",
	;

method elements() {
	( ( $self->has_qDate ? ("qdate") : () ),
	  ( $self->has_msg ? ("msg") : () ),
	 );
}

method attributes() {
	qw(count id);
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::msgQType"
	=> as __PACKAGE__;

1;
