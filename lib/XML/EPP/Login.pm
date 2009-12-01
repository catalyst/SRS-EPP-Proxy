
package XML::EPP::Login;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;

our $PKG = "XML::EPP::Login";
our $SCHEMA_PKG = "XML::EPP";

use XML::EPP::Common;

has_element 'clID' =>
	is => "rw",
	isa => "XML::EPP::Common::clIDType",
	;

has_element 'pw' =>
	is => "rw",
	isa => "XML::EPP::Common::Password",
	;

has_element 'newPW' =>
	is => "rw",
	predicate => "has_newPW",
	isa => "XML::EPP::Common::Password",
	;

has_element 'options' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::credsOptionsType",
	;

has_element 'svcs' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::loginSvcType",
	;

with 'XML::EPP::Node';

# based on epp-1.0.xsd:loginType
subtype "${SCHEMA_PKG}::loginType" =>
	as __PACKAGE__;

1;
