
package SRS::EPP::Command::Logout;

use Moose;
use MooseX::Method::Signatures;
extends 'SRS::EPP::Command';

sub action {
	"logout";
}

sub simple {1}

method process( SRS::EPP::Session $session ) {
	$session->shutdown;
	$self->make_response(code => 1500);
}

1;
