
package XML::EPP::RequestedSvcs;

# FIXME: make a ::ServiceList role; this is very similar to SvcMenu

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $SCHEMA_PKG = "XML::EPP";

has_element 'objURI' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::anyURI]",
	;

has_element 'svcExtension' =>
	is => "rw",
	isa => "XML::EPP::ExtURI",
	predicate => "has_svcExtension",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::loginSvcType"
	=> as __PACKAGE__;

1;
