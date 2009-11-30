
package XML::EPP::Object;

use Moose::Role;
use MooseX::Method::Signatures;

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'PRANG::Graph::Class';

# like the ResultData module, this is really here to keep the type
# heirarchy well-organized.

use Moose::Util::TypeConstraints;
subtype "XML::EPP::readWriteType"
	=> as __PACKAGE__;

1;
