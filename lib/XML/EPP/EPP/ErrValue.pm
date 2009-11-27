package SRS::EPP::Message::EPP::ErrValue;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

use SRS::EPP::Message::EPP::Msg;

# anything which takes a 'whatever' should by definition be able to
# have any other node put in which isn't a Whatever object; in fact
# that is what is intended with this support, to be able to return
# invalid fragments in an error response.
subtype "${SCHEMA_PKG}::errValueType"
	=> as "PRANG::XMLSchema::Whatever|SRS::EPP::MessageNode";

has 'value' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::errValueType",
	;

has 'reason' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::msgType",
	;

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::errValueType"
	=> as __PACKAGE__;

1;
