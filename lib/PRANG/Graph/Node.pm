
package PRANG::Graph::Node;

use Moose::Role;

#method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx )
#  returns ($key, $value, $nodeNameIfAmbiguous)
requires 'accept';

#method complete( PRANG::Graph::Context $ctx )
#  returns Bool
requires 'complete';

#method expected( PRANG::Graph::Context $ctx )
#  returns (@Str) 
requires 'expected';

1;
