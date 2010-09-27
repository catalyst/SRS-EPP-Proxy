
package SRS::EPP::Session::BackendQ;

use SRS::EPP::SRSRequest;
use SRS::EPP::SRSResponse;
use SRS::EPP::Command;

use Moose;
use MooseX::Method::Signatures;

has 'queue' =>
	is => "ro",
	isa => "ArrayRef[ArrayRef[SRS::EPP::SRSRequest]]",
	default => sub { [] },
	;

has 'owner' =>
	is => "ro",
	isa => "ArrayRef[SRS::EPP::Command]",
	default => sub { [] },
	;

has 'responses' =>
	is => "ro",
	isa => "ArrayRef[ArrayRef[SRS::EPP::SRSResponse]]",
	default => sub { [] },
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
method queue_backend_request( SRS::EPP::Command $cmd, SRS::EPP::SRSRequest @rq ) {
	push @{ $self->queue }, \@rq;
	push @{ $self->responses }, [];
	push @{ $self->owner }, $cmd;
}

use List::Util qw(sum);

method queue_size() {
	sum 0, map { scalar @$_ } @{$self->queue};
}

method queue_flat() {
	map {@$_} @{$self->queue};
}

# get the next N backend messages to be sent; marks them as sent
method backend_next( Int $how_many = 1 ) {
	return unless $how_many;
	my $sent = $self->sent;
	my $waiting = $self->queue_size - $sent;
	$how_many = $waiting if $how_many > $waiting;
	my @rv = ($self->queue_flat)[ $sent .. $sent + $how_many - 1 ];
	$self->sent($sent + @rv);
	return @rv;
}

method backend_pending() {
	my $sent = $self->sent;
	my $waiting = $self->queue_size - $sent;
	return $waiting;
}

# add a response corresponding to a request - must be in order as
# there is no other way to correlate read-only responses with their
# requests (no client_tx_id in SRS requests)
method add_backend_response( SRS::EPP::SRSRequest $request, SRS::EPP::SRSResponse $response ) {
	my $rq_a = $self->queue->[0];
	my $rs_a = $self->responses->[0];
	for ( my $i = 0; $i <= $#$rq_a; $i++ ) {
		if ( $rq_a->[$i] == $request ) {
			$rs_a->[$i] = $response;
		}
	}
}

method backend_response_ready() {
	my $rq_a = $self->queue->[0]
		or return;
	my $rs_a = $self->responses->[0];
	@$rq_a == @$rs_a;
}

method dequeue_backend_response() {
	if ( $self->backend_response_ready ) {
		my $rq_a = shift @{ $self->queue };
		my $owner = shift @{ $self->owner };
		my $rs_a = shift @{ $self->responses };
		my $sent = $self->sent;
		$sent -= scalar @$rq_a;
		if ( $sent < 0 ) {
			warn "Bug: sent < 0 ?";
			$sent = 0;
		}
		$self->sent($sent);

		if (wantarray) {
			($owner, @$rs_a);
		}
		else {
			$rs_a;
		}
	}
	else {
		();
	}
}

# Get the command object that 'owns' a SRS request
method get_owner_of_request( SRS::EPP::SRSRequest $request ) {
	my @queue = @{ $self->queue };
	for my $i (0 .. $#queue) {
		next unless ref $queue[$i] eq 'ARRAY';
		foreach my $rq (@{$queue[$i]}) {
			if ($rq->message->unique_id eq $request->message->unique_id) {
				return $self->owner->[$i];	
			}	
		}
	}
}

1;

__END__

=head1 NAME

SRS::EPP::Session::BackendQ - manage tx queue for back-end processing

=head1 SYNOPSIS

 my $q = SRS::EPP::Session::BackendQ->new( session => $session );

 # put requests on queue
 $q->queue_backend_request( $epp_command, @srs_requests );

 # pull up to 6 requests off queue for processing
 my @rq = $q->backend_next( 6 );

 # put responses in, one by one.
 for (1..6) {
     $q->add_backend_response( $rq[$i], $rs[$i] );
 }

 # if a message has had all its requests answered, it can be dequeued
 ($epp_command, @srs_responses)
      = $q->dequeue_backend_response();

=head1 DESCRIPTION

This class implements a simple FIFO queue, but with small
customizations to operation to suit the use case of the SRS EPP Proxy
tracking the requests it sends to the back-end.

=head1 SEE ALSO

L<SRS::EPP::Session>

=head1 AUTHOR AND LICENCE

Development commissioned by NZ Registry Services, and carried out by
Catalyst IT - L<http://www.catalyst.net.nz/>

Copyright 2009, 2010, NZ Registry Services.  This module is licensed
under the Artistic License v2.0, which permits relicensing under other
Free Software licenses.

=cut


# Local Variables:
# mode:cperl
# indent-tabs-mode: t
# cperl-continued-statement-offset: 8
# cperl-brace-offset: 0
# cperl-close-paren-offset: 0
# cperl-continued-brace-offset: 0
# cperl-continued-statement-offset: 8
# cperl-extra-newline-before-brace: nil
# cperl-indent-level: 8
# cperl-indent-parens-as-block: t
# cperl-indent-wrt-brace: nil
# cperl-label-offset: -8
# cperl-merge-trailing-else: t
# End:
