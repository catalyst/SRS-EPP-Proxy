
package XML::EPP::SvcMenu;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

has_element 'version' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::versionType]",
	;

has_element 'lang' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::language]",
	;

has_element 'objURI' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::anyURI]",
	;

has_element 'svcExtension' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::ExtURI",
	predicate => "has_svcExtension",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::svcMenuType"
	=> as __PACKAGE__;

1;
