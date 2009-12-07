
package XML::EPP::Command;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

use XML::EPP::Extension;
use XML::EPP::SubCommand;
use XML::EPP::Login;

our $PKG = __PACKAGE__;

# ok so this one is a bit different to the parent; we can't tell the
# name of the node just from the type of it.  We'll need to store it
# separately.
subtype "${PKG}::choice0"
	=> as join("|", "Bool", map { "${SCHEMA_PKG}::$_" }
			   qw(readWriteType loginType
			      pollType transferType)),
	;

enum "${PKG}::actions" => qw( check create delete info login logout
			      poll renew transfer update);

# and here is the extra field
has 'action' =>
	is => "rw",
	isa => "${PKG}::actions",
	predicate => "has_action",
	;

# these are all maxOccurs = 1 (the default), so we don't need to worry
# about keeping multiple of them.
has_element 'argument' =>
	is => "rw",
	isa => "${PKG}::choice0",
	predicate => "has_argument",
	xml_nodeName => {
		check => "${SCHEMA_PKG}::SubCommand",
		create => "${SCHEMA_PKG}::SubCommand",
		delete => "${SCHEMA_PKG}::SubCommand",
		info => "${SCHEMA_PKG}::SubCommand",
		renew => "${SCHEMA_PKG}::SubCommand",
		update => "${SCHEMA_PKG}::SubCommand",

		login => "${SCHEMA_PKG}::Login",
		logout => "Bool",
		transfer => "${SCHEMA_PKG}::Transfer",
		poll => "${SCHEMA_PKG}::Poll",
	},
	xml_nodeName_attr => "action",
	;

has_element 'extension' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::extAnyType",
	predicate => "has_extension",
	;

has_element 'clTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	predicate => "has_clTRID",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::commandType"
	=> as __PACKAGE__;

sub is_command { 1 }

1;
