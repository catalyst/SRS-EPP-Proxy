
package SRS::EPP::Message::EPPCom::Node;

use Moose::Role;
with 'SRS::EPP::MessageNode';

sub xmlns {
	"urn:ietf:params:xml:ns:eppcom-1.0";
}

1;
