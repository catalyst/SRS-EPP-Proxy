
package XML::EPP::Plugin;

use Moose::Role;
use PRANG::Graph;

with 'PRANG::Graph';

requires 'is_command';

1;
