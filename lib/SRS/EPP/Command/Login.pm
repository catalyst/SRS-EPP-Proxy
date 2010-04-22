

package SRS::EPP::Command::Login;

use Moose;
extends 'SRS::EPP::Command';

sub action {
	"login";
}

sub authenticated { 0 }

1;
