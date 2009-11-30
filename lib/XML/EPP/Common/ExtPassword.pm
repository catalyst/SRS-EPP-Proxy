
package XML::EPP::Common::ExtPassword;

use Moose::Role;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "XML::EPP::Common";

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'PRANG::Graph::Class';

subtype "${SCHEMA_PKG}::extAuthInfoType"
	=> as __PACKAGE__;

1;
