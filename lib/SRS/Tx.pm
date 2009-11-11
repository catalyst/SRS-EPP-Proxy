
package SRS::Tx;

use Moose;

extends "SRS::EPP::Message";

has 'parts' =>
	is => "rw",
	isa => "ArrayRef[SRS::EPP::Message]",
	;

1;
