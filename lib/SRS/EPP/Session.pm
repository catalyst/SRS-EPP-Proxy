# vim: filetype=perl:noexpandtab:ts=3:sw=3
#
# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

package SRS::EPP::Session;

# this object is unfortunately something of a ``God Object'', but
# measures are taken to stop that from being awful; mostly delegation
# to other objects

use Moose;
use MooseX::Method::Signature;

has io =>
	is => "ro",
	;

has user =>
	is => "rw",
	isa => "Str",
	;

has state =>
	is => "rw",
	isa => "Str",
	default => "Waiting for Client",
	;

use Moose::Util::TypeConstraints;

#----
# input packet chunking
has 'input_packeter' =>
	default => sub {
		my $self = shift;
		SRS::EPP::Packets->new(session => $self);
	},
	handles => [qw( input_event input_state input_expect )],
	;

method read_input( Int $how_much where { $_ > 0 } ) {
	my $self = shift;
	my $how_much = shift;
	$self->io->read($how_much);
}

#----
# convert input packets to messages
method input_packet( Str $data ) {
	my $cmd = SRS::EPP::Command->parse($data);
	$self->queue_command($cmd);
}

#----
# queues

has 'processing_queue' =>
	default => sub {
		my $self = shift;
		SRS::EPP::Session::CmdQ->new();
	},
	handles => [qw( queue_command next_command
			add_command_response
			response_ready dequeue_response )],
	;

has 'backend_queue' =>
	default => sub {
		my $self = shift;
		SRS::EPP::Session::BackendQ->new();
	},
	handles => [qw( queue_backend_request backend_next
			backend_pending
			add_backend_response backend_response_ready
			dequeue_backend_response ) ],
	;

# "stalling" means that no more processing can be advanced until the
# responses to the currently processing commands are available.
#
#  eg, "login" and "logout" both stall the queue, as will the
#  <transform><renew> command, if we have to first query the back-end
#  to determine what the correct renewal message is.

has stalled =>
	is => "rw",
	isa => "Bool",
	;

method process_queue( Int $count = 1 ) {
	while ( $count-- > 0 ) {
		if ( $self->stalled ) {
			$self->state("Processing Command");
			last;
		}
		my $command = $self->next_command;
		if ( $command->simple ) {
			# "simple" commands include "hello" and "logout"
			my $response = $command->process($self);
			$self->add_command_response($command, $response);
		}
		elsif ( $command->authenticated and !$self->user ) {
			$self->add_command_response(
				$command,
				SRS::EPP::Response::Error->new(
					id => 2201,
					extra => "Not logged in",
					),
				);
		}
		else {
			# regular message, possibly including "login"
			my @messages = $command->to_srs($self);
			$self->queue_backend_request($command, @messages);
			if ( $command->type eq "login" ) {
				$self->state("Processing <login>");
				$self->stalled(1);
			}
			else {
				$self->state("Processing Command");
			}
		}
	}
	$self->send_pending_replies;
	if ( $self->backend_pending ) {
		$self->send_backend_queue;
	}
}

#----
# method to say "we're connected, so send a greeting"; if this class
# were abstracted to not run over a stream transport then this would
# be important.
method connected() {
	$self->state("Prepare Greeting");
	my $response = SRS::EPP::Response::Greeting->new();
	$self->queue_reply($response);
	$self->state("Waiting for Client Authentication");
}

#----
# Backend stuff.  Perhaps this should all go in the BackendQ class.

has 'backend_tx_max' =>
	isa => "Int",
	is => "rw",
	default => 10,
	;

has 'user_agent' =>
	is => "rw",
	default => sub {
		my $self = shift;
		SRS::EPP::Proxy::UA->new($self);
	},
	;

has 'backend_url' =>
	isa => "Str",
	is => "rw",
	;

use HTTP::Request::Common qw(POST);

method send_backend_queue() {
	my @next = $self->backend_next($self->backend_tx_max);

	my $tx = SRS::Tx->new( messages => \@next );
	my $sig = $self->sign_tx($tx);
	my $reg_id = $self->user;

	my $req = POST(
		$self->backend_url,
		[
			r => $tx,
			s => $sig,
			n => $reg_id,
		       ],
	       );

	$self->user_agent->register( $req );
}

#----
# Dealing with backend responses

method be_response( SRS::Tx $rs_tx ) {
	my @parts = $rs_tx->messages;
	for my $rs ( @parts ) {
		my $action_id = $rs->action_id;
		$self->add_backend_response($action_id, $rs);
	}
	while ( $self->backend_response_ready ) {
		my ($cmd, $response, $rq) = $self->dequeue_backend_response;
		$cmd->notify($response);
		if ( $cmd->done ) {
			$self->state("Prepare Response");
			my $epp_rs = $response->to_epp;
			$self->add_command_response($cmd, $epp_rs);
		}
		else {
			my @messages = $command->next_backend_message($self);
			$self->queue_backend_request($command, @messages);
		}
	}
	$self->send_pending_replies;
	if ( $self->backend_pending ) {
		$self->send_backend_queue;
	}
}

method send_pending_replies() {
	while ( $self->response_ready ) {
		my $response = $self->dequeue_response;
		$self->queue_reply($response);
	}
	if ( ! $self->commands_queued ) {
		if ( $self->user ) {
			$self->state("Waiting for Command");
		}
		else {
			$self->state("Waiting for Client Authentication");
		}
	}
}

#----
# Sending responses back
has 'output_queue' =>
	is => "ro",
	isa => "ArrayRef[Str]",
	default => sub { [] },
	;

method queue_reply( SRS::EPP::Response $rs ) {
	my $reply_data = $rs->to_xml;
	my $length = pack("N", length($reply_data));
	push @{ $self->output_queue }, $length, $reply_data;
	$self->output_event;
}

method output_event() {
	my $oq = $self->output_queue;
	my $written = 0;
	my $io = $self->io;
	while ( @$oq ) {
		my $datum = shift @$oq;
		my $wrote = $io->write( $datum );
		$written += $wrote;
		if ( !$wrote ) {
			unshift @$oq, $datum;
			last;
		}
		elsif ( $wrote < length $datum ) {
			unshift @$oq, substr $datum, $written;
			last;
		}
	}
	return $written;
}

1;

__END__

=head1 NAME

SRS::EPP::Session - logic for EPP Session State machine

=head1 SYNOPSIS

 my $session = SRS::EPP::Session->new( io => $socket );

 #--- session events:

 $session->connected;
 $session->input_event;
 $session->input_packet($data);
 $session->queue_command($command);
 $session->process_queue($count);
 $session->be_response($srs_rs);
 $session->send_pending_replies();
 $session->queue_reply($response);
 $session->output_event;

 #--- information messages:

 # print RFC3730 state eg 'Waiting for Client',
 # 'Prepare Greeting' (see Page 4 of RFC3730)
 print $session->state;

 # return the credential used for login
 print $session->user;

=head1 DESCRIPTION

The SRS::EPP::Session class manages the flow of individual
connections.  It implements the "EPP Server State Machine" from
RFC3730, as well as the exchange encapsulation described in RFC3734
"EPP TCP Transport".

This class is designed to be called from within an event-based
framework; this is fairly essential in the context of a server given
the potential to deadlock if the client does not clear its responses
in a timely fashion.

Input commands go through several stages:

=over

=item *

First, incoming data ready is chunked into complete EPP requests.
This is a binary de-chunking, and is based on reading a packet length
as a U32, then waiting for that many octets.  See L</input_event>

=item *

Complete chunks are passed to the L<SRS::EPP::Command> constructor for
validation and object construction.  See L</input_packet>

=item *

The constructed object is triaged, and added to an appropriate
processing queue.  See L</queue_command>

=item *

The request is processed; either locally for requests such as
C<E<gt>helloE<lt>>, or converted to the back-end format
(L<SRS::Request>) and placed in the back-end queue (this is normally
immediately dispatched).  See L</process_queue>

=item *

The response (a L<SRS::Response> object) from the back-end is
received; this is converted to a corresponding L<SRS::EPP::Response>
object.  Outstanding queued back-end requests are then dispatched if
they are present (so each session has a maximum of one outstanding
request at a time).  See L</be_response>

=item *

Prepared L<SRS::EPP::Response> objects are queued, this involves
individually converting them to strings, which are sent back to the
client, each response its own SSL frame.  See L</queue_response>

=item *

If the output blocks, then the responses wait and are sent back as
the response queue clears.  See L</output_event>

=back

=head1 METHODS

=head2 connected()

This event signals to the Session that the client is now connected.
It signals that it is time to issue a C<E<gt>greetingE<lt>> response,
just as if a C<E<gt>helloE<lt>> message had been received.

=head2 input_event()

This event is intended to be invoked whenever there is data ready to
read on the input socket.  It returns false if not enough data could
be read to get a complete subpacket.

=head2 input_packet($data)

This message is self-fired with a complete packet of data once it has
been read.

=head2 queue_command($command)

Enqueues an EPP command for processing and does nothing else.

=head2 process_queue($count)

Processes the back-end queue, up to C<$count> at a time.  At the end
of this, if there are no outstanding back-end transactions, any
produced L<SRS::Request> objects are wrapped into an
L<SRS::Transaction> object and dispatched to the back-end.

Returns the number of commands remaining to process.

=head2 be_response($srs_rs)

This is fired when a back-end response is received.  It is responsible
for matching responses with commands in the command queue and
converting to L<SRS::EPP::Response> objects.

=head2 queue_response($response)

This is called by process_queue() or be_response(), and converts a
L<SRS::EPP::Response> object to network form, then starts to send it.
Returns the number of octets which are currently outstanding.

=head2 output_event()

This event is intended to be called when the return socket is newly
writable; it writes everything it can to the output socket and returns
the number of bytes written.

=head1 SEE ALSO

L<SRS::EPP::Command>, L<SRS::EPP::Response>

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

