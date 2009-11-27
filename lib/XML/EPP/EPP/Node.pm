
package SRS::EPP::Message::EPP::Node;

use Moose::Role;
with 'SRS::EPP::MessageNode';

sub xmlns {
	"urn:ietf:params:xml:ns:epp-1.0";
}

1;
