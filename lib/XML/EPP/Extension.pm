
package XML::EPP::Extension;

use Moose::Role;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "XML::EPP";

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'PRANG::Graph::Class';

subtype "${SCHEMA_PKG}::extAnyType"
	=> as __PACKAGE__;

1;
