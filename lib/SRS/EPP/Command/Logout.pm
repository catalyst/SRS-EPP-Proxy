

package SRS::EPP::Command::Logout;

use Moose;
extends 'SRS::EPP::Command';

sub action {
	"logout";
}

1;
