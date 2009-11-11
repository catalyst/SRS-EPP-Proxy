
package SRS::EPP::Session::BackendQ;

use SRS::EPP::Command;
use SRS::Request;

use Moose;
use MooseX::Method::Signatures;

has 'queue' =>
	is => "ro",
	isa => "ArrayRef[SRS::Request]",
	default => sub { [] },
	;

has 'owner' =>
	is => "ro",
	isa => "ArrayRef[SRS::EPP::Command]",
	default => sub { [] },
	;

has 'responses' =>
	is => "ro",
	isa => "HashRef[SRS::Response]",
	default => sub { {} },
	;

has 'sent' =>
	is => "rw",
	isa => "Int",
	default => 0,
	;

has 'session' =>
	is => "ro",
	isa => "SRS::EPP::Session",
	;

# add a response corresponding to a request
method queue_backend_request( SRS::EPP::Command $cmd, SRS::Request @rq ) {
	for my $rq ( @rq ) {
		push @{ $self->queue }, $rq;
		push @{ $self->owner }, $cmd
	}
}

# get the next N backend messages to be sent; marks them as sent
method backend_next( Int $how_many = 1 ) {
	my $sent = $self->sent;
	my $waiting = @{ $self->queue } - $sent;
	my @rv = @{ $self->queue }[ $sent .. $sent + $how_many ];
	$self->sent($sent + @rv);
	return @rv;
}

method backend_pending() {
	my $sent = $self->sent;
	my $waiting = @{ $self->queue } - $sent;
	return $waiting;
}

# add a response corresponding to a request
method add_backend_response(
	SRS::ActionID $id, SRS::Response $response
       )
{
	$self->responses->{$id} = $response;
}

method backend_response_ready() {
	my $id = $self->queue->[0]->action_id;
	exists $self->responses->{$id};
}

method dequeue_backend_response() {
	if ( $self->backend_response_ready ) {
		my $rq = shift @{ $self->queue };
		my $owner = shift @{ $self->owner };
		my $sent = $self->sent;
		$sent--;
		if ( $sent < 0 ) {
			warn "Bug: sent < 0 ?";
			$sent = 0;
		}
		$self->sent($sent);
		my $id = $rq->action_id;
		my $response = delete $self->responses->{$id};
		if ( wantarray ) {
			($owner, $response, $rq);
		}
		else {
			$owner->notify($response);
			$response;
		}
	}
	else {
		();
	}
}

1;

__END__
