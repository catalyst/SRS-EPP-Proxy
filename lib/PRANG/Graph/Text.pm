
package PRANG::Graph::Text;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

method textnode_ok( Int $pos ) { $pos == 1 }
method element_ok { 0 }
method pop_ok( Int $pos ) { $pos == 1 }  # yes, must use a Quantity
method element_class { "Str" }

1;
