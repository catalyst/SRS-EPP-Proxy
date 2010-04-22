

package SRS::EPP::Command::Extension;

use Moose;
extends 'SRS::EPP::Command';

sub match_class {
	"XML::EPP::Extension";
}

1;
