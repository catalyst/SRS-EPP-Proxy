
package XML::EPP::Extension;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

has 'ext_obj_names' =>
	is => "rw",
	isa => "ArrayRef[Str]",
	;

has_element 'ext_objs' =>
	is => "rw",
	isa => "ArrayRef[PRANG::Graph::Class]",
	xml_nodeName => "*",
	xml_nodeName_attr => "ext_obj_names",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::extAnyType"
	=> as __PACKAGE__;

method is_command {
	$self->ext_objs->[0]->is_command;
}

1;
