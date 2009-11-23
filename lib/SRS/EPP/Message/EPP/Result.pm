
package SRS::EPP::Message::EPP::Result;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

use SRS::EPP::Message::EPP::ErrValue;

our $PKG = __PACKAGE__;

has 'msg' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgType",
	;

subtype "${PKG}::choice0"
	=> as join("|", map { "${SCHEMA_PKG}::$_" }
			   qw(errValueType extErrValueType)),
	;

has 'errs' =>
	is => "rw",
	isa => "ArrayRef[${PKG}::choice0]",
	;

our %valid_result_codes = map { $_ => 1 }
	qw( 1000 1001 1300 1301 1500 2000 2001 2002 2003 2004
	    2005 2100 2101 2102 2103 2104 2105 2106 2200 2201
	    2202 2300 2301 2302 2303 2304 2305 2306 2307 2308
	    2400 2500 2501 2502 );

subtype "${PKG}::resultCodeType"
	=> as "Int"
	=> where {
		$_ >= 1000 and $_ <= 2502 and
			exists $valid_result_codes{$_};
	};

has 'code' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::resultCodeType",
	;

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::resultType"
	=> as __PACKAGE__;

1;
