
package XML::EPP::ExtURI;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "XML::EPP";

use PRANG::Graph;

has_element 'extURI' =>
	is => "rw",
	isa => "ArrayRef[PRANG::XMLSchema::anyURI]",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::extURIType"
	=> as __PACKAGE__;

1;
