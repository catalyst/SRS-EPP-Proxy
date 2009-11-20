
package SRS::EPP::Message::EPP::Response;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

use Moose::Util::TypeConstraints;

our $PKG = __PACKAGE__;
our $SCHEMA_PKG = $SRS::EPP::Message::EPP::PKG;

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

1;
