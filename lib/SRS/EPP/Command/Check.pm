
package SRS::EPP::Command::Check;

use Moose;
extends 'SRS::EPP::Command';

with 'SRS::EPP::Command::PayloadClass';

sub action {
	"check";
}

use Module::Pluggable search_path => [__PACKAGE__];

1;
