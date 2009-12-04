
package XML::EPP::Transfer;

# based on epp-1.0.xsd:greetingType

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;
use XML::EPP::Plugin;

our $SCHEMA_PKG = "XML::EPP";

has 'action' =>
	is => "rw",
	isa => "Str",
	;

has_element 'payload' =>
	is => "rw",
	isa => "XML::EPP::Plugin",
	xmlns => "*",
	xml_nodeName => "*",
	xml_nodeName_attr => "action",
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
