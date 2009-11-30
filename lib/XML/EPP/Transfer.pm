
package XML::EPP::Transfer;

# based on epp-1.0.xsd:greetingType

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
our $SCHEMA_PKG = "XML::EPP";

has 'object_name' =>
	is => "rw",
	isa => "Str",
	;

has 'object' =>
	is => "rw",
	isa => "XML::EPP::Object",
	xmlns => "*",
	xml_nodeName => "*",
	xml_nodeName_attr => "object_name",
	;

enum "${SCHEMA_PKG}::transferOpType" =>
	qw(approve cancel query reject request);

has_attr 'op' =>
	is => "rw",
	isa => "XML::EPP::transferOpType",
	required => 1,
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::transferType"
	=> as __PACKAGE__;

1;
