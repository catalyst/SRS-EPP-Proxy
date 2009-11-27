
package SRS::EPP::Message::EPP::Object;

use Moose::Role;
use MooseX::Method::Signatures;

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'SRS::EPP::MessageNode';

# like the ResultData module, this is really here to keep the type
# heirarchy well-organized.

use Moose::Util::TypeConstraints;
subtype "SRS::EPP::Message::EPP::readWriteType"
	=> as __PACKAGE__;

1;
