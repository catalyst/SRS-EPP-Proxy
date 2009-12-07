
package XML::EPP::Extension;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
use XML::EPP::Extension::Type;

our $SCHEMA_PKG = "XML::EPP";

has_element 'ext_objs' =>
	is => "rw",
	isa => "ArrayRef[XML::EPP::Extension::Type]",
	xmlns => "*",
	xml_nodeName => "*",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::extAnyType"
	=> as __PACKAGE__;

method is_command {
	$self->ext_objs->[0]->is_command;
}

1;
