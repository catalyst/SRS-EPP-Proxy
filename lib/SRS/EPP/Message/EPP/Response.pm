
package SRS::EPP::Message::EPP::Response;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

our $PKG = __PACKAGE__;

has 'result' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::resultType]",
	;

has 'msgQ' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgQType",
	;

has 'resData' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::ResultData",
	;

has 'extension' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::extAnyType",
	;

has 'trID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDType",
	;

method attributes() { }
method elements() {
	qw( result msgQ resData extension trID );
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::responseType"
	=> as __PACKAGE__;

1;
