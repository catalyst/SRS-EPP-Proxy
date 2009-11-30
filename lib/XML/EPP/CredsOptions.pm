
package XML::EPP::CredsOptions;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

has_element 'version' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::versionType",
	default => "1.0",
	;

has_element 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	default => "en",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::credsOptionsType" =>
	as __PACKAGE__;

1;
