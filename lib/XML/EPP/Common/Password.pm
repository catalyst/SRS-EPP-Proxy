
package XML::EPP::Common::Password;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
use PRANG::XMLSchema::Types;

our $SCHEMA_PKG = "XML::EPP::Common";

has_attr 'roid' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::roidType",
	predicate => "has_roid",
	;

has_element 'content' =>
	is => "rw",
	isa => "PRANG::XMLSchema::normalizedString",
	xml_nodeName => "",
	;

with 'XML::EPP::Common::Node';

subtype "${SCHEMA_PKG}::pwAuthInfoType"
	=> as __PACKAGE__;

1;
