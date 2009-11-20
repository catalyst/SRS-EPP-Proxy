
package SRS::EPP::Message::EPP::Object;

use Moose::Role;
use MooseX::Method::Signatures;

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'SRS::EPP::MessageNode';

# like the ResultData module, this is really here to keep the type
# heirarchy well-organized.

1;
