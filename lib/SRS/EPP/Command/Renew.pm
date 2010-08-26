
package SRS::EPP::Command::Renew;

use Moose;
extends 'SRS::EPP::Command';

use Module::Pluggable search_path => [__PACKAGE__];
with 'SRS::EPP::Command::PayloadClass';

sub action {
	"renew";
}

1;
