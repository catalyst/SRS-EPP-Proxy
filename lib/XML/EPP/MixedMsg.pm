
package XML::EPP::MixedMsg;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

extends 'PRANG::XMLSchema::Whatever';

has_attr 'lang' =>
	is => "rw",
	isa => "PRANG::XMLSchema::language",
	default => "en",  # imperialists!!
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::mixedMsgType"
	=> as __PACKAGE__;

1;
