

package SRS::EPP::Command::Hello;

use Moose;
extends 'SRS::EPP::Command';

sub match_class {
	"XML::EPP::Hello";
}

sub authenticated { 0 }
sub simple { 1 }

1;
