
package XML::EPP::Poll;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

enum "${SCHEMA_PKG}::pollOpType" =>
	qw(ack req);

has_attr 'op' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::pollOpType",
	required => 1,
	;

has_attr 'msgID' =>
	is => "rw",
	isa => "PRANG::XMLSchema::token",
	predicate => "has_msgID",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::pollType"
	=> as __PACKAGE__;

1;
