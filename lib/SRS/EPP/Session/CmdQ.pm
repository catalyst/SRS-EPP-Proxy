
package SRS::EPP::Session::CmdQ;

use Moose;
use MooseX::Method::Signatures;
use SRS::EPP::Command;
use SRS::EPP::Response;

has 'queue' =>
	is => "ro",
	isa => "ArrayRef[SRS::EPP::Command]",
	default => sub { [] },
	;

has 'responses' =>
	is => "ro",
	isa => "ArrayRef[Maybe[SRS::EPP::Command]]",
	default => sub { [] },
	;

has 'next' =>
	is => "rw",
	isa => "Int",
	default => 0,
	;

method next_command() {
	my $q = $self->queue;
	my $next = $self->next;
	if ( $q->[$next] ) {
		return $q->[$next++];
	}
	else {
		();
	}
}

method commands_queued() {
	my $q = $self->queue;
	my $next = $self->next;
	return ( $next <= $#$q );
}

method queue_command( SRS::EPP::Command $cmd ) {
	push @{ $self->queue }, $cmd;
	push @{ $self->responses }, undef;
}

# with a command object, place a response at the same place in the queue
method add_command_response(
	SRS::EPP::Command $cmd, SRS::EPP::Response $response
       )
{
	my $q = $self->queue;
	for ( my $i = 0; $i <= $#$q; $i++ ) {
		if ( $q->[$i] == $cmd ) {
			$self->responses->[$i] = $response;
			last;
		}
	}
}

method response_ready() {
	defined($self->responses->[0]);
}

method dequeue_response() {
	if ( $self->response_ready ) {
		my $cmd = shift @{ $self->queue };
		my $response = shift @{ $self->responses };
		if ( wantarray ) {
			($response, $cmd);
		}
		else {
			$response;
		}
	}
	else {
		();
	}
}

1;

__END__
