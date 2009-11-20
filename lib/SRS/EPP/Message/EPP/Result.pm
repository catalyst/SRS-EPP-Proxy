
package SRS::EPP::Message::EPP::Result;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

use Moose::Util::TypeConstraints;

our $PKG = __PACKAGE__;
our $SCHEMA_PKG = $SRS::EPP::Message::EPP::PKG;

has 'msg' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgType",
	;

subtype '${PKG}::choice0' =>
	as => join("|", map { "${SCHEMA_PKG}::$_" }
			   qw(errValueType extErrValueType)),
	;

has 'errs' =>
	is => "rw",
	isa => "ArrayRef[${PKG}::choice0]",
	;

has 'code' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::resultCodeType",
	;

1;
