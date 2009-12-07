
package XML::EPP::SubCommand;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
use XML::EPP::Plugin;

our $PKG = __PACKAGE__;
our $SCHEMA_PKG = "XML::EPP";

has 'action' =>
	is => "rw",
	isa => "Str",
	;

has_element "payload" =>
	is => "rw",
	xmlns => "*",
	isa => "XML::EPP::Plugin",
	;

with "${SCHEMA_PKG}::Node";

subtype "XML::EPP::readWriteType"
	=> as __PACKAGE__;

1;
