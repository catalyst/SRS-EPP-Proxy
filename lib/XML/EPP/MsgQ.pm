
package XML::EPP::MsgQ;

use XML::EPP::MixedMsg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

has_element 'qDate' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	predicate => "has_qDate",
	;

has_element 'msg' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::mixedMsgType",
	predicate => "has_msg",
	;

has_attr 'count' =>
	is => "rw",
	isa => "PRANG::XMLSchema::unsignedLong",
	;

has_attr 'id' =>
	is => "rw",
	isa => "XML::EPP::Common::minTokenType",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::msgQType"
	=> as __PACKAGE__;

1;
