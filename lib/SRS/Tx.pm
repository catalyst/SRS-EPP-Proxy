
package SRS::Tx;

use Moose;

with "SRS::EPP::Message";

has 'parts' =>
	is => "rw",
	isa => "ArrayRef[SRS::EPP::Message]",
	;

sub marshaller {
}

1;
