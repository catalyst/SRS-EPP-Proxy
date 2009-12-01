
package XML::EPP::Hello;

use Moose;
use MooseX::Method::Signatures;
use PRANG::Graph;

with 'XML::EPP::Node';

sub is_command { 1 }

1;
