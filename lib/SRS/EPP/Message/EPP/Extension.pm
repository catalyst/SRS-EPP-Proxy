
package SRS::EPP::Message::EPP::Extension;

use Moose::Role;
use MooseX::Method::Signatures;

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'SRS::EPP::MessageNode';

1;
