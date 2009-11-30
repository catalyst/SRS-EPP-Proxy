
package XML::EPP::ResultData;

use Moose::Role;
use MooseX::Method::Signatures;

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'PRANG::Graph::Class';

# in principal we could use Extension, but that could be confusing.

1;
