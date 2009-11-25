
package PRANG::Graph::Node;

use Moose::Role;

# method textnode_ok( Int $pos ) returns Bool
requires 'textnode_ok';

# method element_ok( Str $xmlns?, Str $nodename, Int $pos where { $_ > 0 })
#   returns Bool
requires 'element_ok';

# method pop_ok( Int $pos where { $_ > 0 })
#   returns Bool;
requires 'pop_ok';

# method element_class( Str $xmlns?, Str $nodename, Int $pos )
#   returns Str
requires 'element_class';

1;
