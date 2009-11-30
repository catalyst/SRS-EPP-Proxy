
package XML::EPP::Common::Node;

use Moose::Role;
with 'PRANG::Graph::Class';

sub xmlns {
	"urn:ietf:params:xml:ns:eppcom-1.0";
}

1;
