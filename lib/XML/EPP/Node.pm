
package XML::EPP::Node;

use Moose::Role;
with 'PRANG::Graph::Class';

sub xmlns {
	"urn:ietf:params:xml:ns:epp-1.0";
}

1;
