
package SRS::EPP::Message::EPP::Command;

use Moose;
with 'SRS::EPP::Message::EPP::Node';
use MooseX::Method::Signatures;

use Moose::Util::TypeConstraints;

our $PKG = __PACKAGE__;
our $SCHEMA_PKG = $SRS::EPP::Message::EPP::PKG;

# ok so this one is a bit different to the parent; we can't tell the
# name of the node just from the type of it.  We'll need to store it
# separately.
subtype "${PKG}::choice0" =>
	as => join("|", map { "${SCHEMA_PKG}::$_" }
			   qw(readWriteType loginType Logout
			      pollType transferType)),
	;

# and here is the extra field
has 'action' =>
	is => "rw",
	isa => "Str",
	predicate => "has_action",
	where  {
		m{^(check|create|delete|info|login|
			  logout|poll|renew|transfer|update)$}x;
	};

# these are all maxOccurs = 1 (the default), so we don't need to worry
# about keeping multiple of them.
has 'object' =>
	is => "rw",
	isa => "${PKG}::choice0",
	predicate => "has_object",
	;

has 'extension' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::extAnyType",
	predicate => "has_extension",
	;

has 'clTRID' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::trIDStringType",
	predicate => "has_clTRID",
	;

# conversion details
method attributes() { }
method elements() {
	unless ($self->has_action and $self->has_object) {
		die "command incomplete";
	}
	([ undef, $self->action, $self->object ],
	 ($self->has_extension
		  ? ([ undef, "extension", $self->extension ]) : () ),
	 ($self->has_clTRID
		  ? ([ undef, "clTRID", $self->clTRID ]) : () ),
	);
}

1;
