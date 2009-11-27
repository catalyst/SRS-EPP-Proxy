
package SRS::EPP::Message::EPP::Extension;

use Moose::Role;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'SRS::EPP::MessageNode';

subtype "${SCHEMA_PKG}::extAnyType"
	=> as __PACKAGE__;

1;
