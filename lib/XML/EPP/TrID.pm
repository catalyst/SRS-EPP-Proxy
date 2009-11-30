
package XML::EPP::TrID;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

has_element 'clTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	predicate => "has_clTRID",
	;

has_element 'svTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::trIDType"
	=> as __PACKAGE__;

1;
