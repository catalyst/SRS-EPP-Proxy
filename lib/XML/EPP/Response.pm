
package XML::EPP::Response;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";
our $PKG = __PACKAGE__;

has_element 'result' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::resultType]",
	;

has_element 'msgQ' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgQType",
	;

has_element 'resData' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::ResultData",
	;

has_element 'extension' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::extAnyType",
	;

has_element 'trID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDType",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::responseType"
	=> as __PACKAGE__;

1;
