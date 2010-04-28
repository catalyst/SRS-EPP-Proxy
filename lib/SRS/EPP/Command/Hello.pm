

package SRS::EPP::Command::Hello;

use Moose;
use MooseX::Method::Signatures;
extends 'SRS::EPP::Command';

sub match_class {
	"XML::EPP::Hello";
}

sub authenticated { 0 }
sub simple { 1 }

method process( SRS::EPP::Session $session ) {
	$self->make_response("Greeting");
}

1;
