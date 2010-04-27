
package SRS::Tx;

use 5.010;
use Moose;

extends "SRS::EPP::Message";

has 'parts' =>
	is => "rw",
	isa => "ArrayRef[SRS::EPP::Message]",
	;

has "+message" =>
	isa => "XML::SRS",
	trigger => sub {
		my $self = shift;
		my $message = $self->message;
		my ($class, $method);
		if ( $message->isa("XML::SRS::Request") ) {
			$class = "SRS::Request";
			$method = "requests";
		}
		else {
			$class = "SRS::Response";
			$method = "results";
		}
		$self->parts( [
			map {
				$class->new( message => $_ )
				}
				@{ $message->$method//[] }
			       ] );
	},
	;

1;
