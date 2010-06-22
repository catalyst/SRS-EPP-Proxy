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

use 5.010;
use strict;

use Moose;
use MooseX::Method::Signatures;

with 'MooseX::Log::Log4perl::Easy';

# messages that we use
# - XML formats
use XML::EPP;
use XML::SRS;

# - wrapper classes
use SRS::EPP::Command;
use SRS::EPP::Response;
use SRS::EPP::Response::Error;
use SRS::EPP::SRSMessage;
use SRS::EPP::SRSRequest;
use SRS::EPP::SRSResponse;

# queue classes and slave components
use SRS::EPP::Packets;
use SRS::EPP::Session::CmdQ;
use SRS::EPP::Session::BackendQ;
use SRS::EPP::Proxy::UA;

# other includes
use HTTP::Request::Common qw(POST);
use bytes qw();
use utf8;
use Encode qw(decode encode);

has io =>
	is => "ro",
	isa => "Net::SSLeay::OO::SSL",
	;

# so the socket doesn't fall out of scope and get closed...
has 'socket' =>
	is => "ro",
	isa => "IO::Handle",
	;

has user =>
	is => "rw",
	isa => "Str",
	;

# hack for login message
has want_user =>
	is => "rw",
	isa => "Str",
	clearer => "clear_want_user",
	;

# this "State" is the state according to the chart in RFC3730 and is
# updated for amusement's sake only
has state =>
	is => "rw",
	isa => "Str",
	default => "Waiting for Client",
	trigger => sub {
		my $self = shift;
		if ( $self->has_proxy ) {
			$self->proxy->show_state(shift, $self);
		}
	},
	;

has 'proxy' =>
	is => "ro",
	isa => "SRS::EPP::Proxy",
	predicate => "has_proxy",
	weak_ref => 1,
	handles => [qw/openpgp/],
	required => 1,
	;

# this object is billed with providing an Event.pm-like interface.
has event =>
	is => "ro",
	required => 1,
	;

has output_event_watcher =>
	is => "rw",
	;

has input_event_watcher =>
	is => "rw",
	;

# 'yield' means to queue an event for running but not run it
# immediately.
has 'yielding' =>
	is => "ro",
	isa => "HashRef",
	default => sub { {} },
	;

method yield(Str $method, @args) {
	my $trace;
	if ( $self->log->is_trace ) {
		my $caller = ((caller(1))[3]);
		$self->log_trace(
			"$caller yields $method"
			 .(@args?" (with args: @args)":"")
			);
	}
	if ( !@args ) {
		if ( $self->yielding->{$method} ) {
			$self->log_trace(" - already yielding");
			return;
		}
		else {
			$self->yielding->{$method} = 1;
		}
	}
	$self->event->timer(
		desc => $method,
		after => 0,
		cb => sub {
			delete $self->yielding->{$method};
			if ( $self->log->is_trace ) {
				$self->log_trace(
				"Calling $method".(@args?"(@args)":"")
					);
			}
			$self->$method(@args);
		});
}

has 'connection_id' =>
	is => "ro",
	isa => "Str",
	default => sub {
		sprintf("sep.%x.%.4x",time(),$$&65535);
	},
	;

has 'peerhost' =>
	is => "rw",
	isa => "Str",
	;

has 'peer_cn' =>
	is => "rw",
	isa => "Str",
	;

has 'server_id_seq' =>
	is => "rw",
	isa => "Num",
	traits => [qw/Number/],
	handles => {
		'inc_server_id' => 'add',
	},
	default => 0,
	;

# called when a response is generated from the server itself, not the
# back-end.  Return an ephemeral ID based on the timestamp and a
# session counter.
method new_server_id() {
	$self->inc_server_id(1);
	my $id = $self->connection_id.".".sprintf("%.3d",$self->server_id_seq);
	$self->log_trace("server-generated ID is $id");
	$id;
}

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
	my $rv = $self->io->read($how_much);
	$self->log_trace("read_input($how_much) = ".bytes::length($rv));
	return $rv;
}

method input_ready() {
	!!$self->io->peek(1);
}

# convert input packets to messages
method input_packet( Str $data ) {
	$self->log_debug("parsing ".bytes::length($data)." bytes of XML");
	my $msg = eval {
		if ( ! utf8::is_utf8($data) ) {
			my $pre_length = bytes::length($data);
			$data = decode("utf8", $data);
			my $post_length = length($data);
			if ( $pre_length != $post_length ) {
				$self->log_debug(
				"data is $post_length unicode characters"
					);
			}
		}
		$self->log_packet("input", $data);
		XML::EPP->parse($data);
	};
	my $error = ( $msg ? undef : $@ );
	$self->log_info("error parsing message: $error")
		if $error;
	my $queue_item = SRS::EPP::Command->new(
		( $msg ? (message => $msg) : () ),
		xml => $data,
		( $error ? (error => $error) : () ),
		session => $self,
		);
	$self->log_info("queuing command: $queue_item");
	$self->queue_command($queue_item);
	if ( $error ) {
		my $error_rs = SRS::EPP::Response::Error->new(
			client_id => $queue_item->client_id,
			server_id => $self->new_server_id,
			code => 2001,
			exception => $error,
			);
		$self->log_info("queuing response: $error_rs");
		# insert a dummy command which returns a 2001
		# response
		$self->add_command_response(
			$error_rs,
			$queue_item,
			);
		$self->yield("send_pending_replies");
	}
	else {
		$self->yield("process_queue");
	}
}

#----
# queues
has 'processing_queue' =>
	default => sub {
		my $self = shift;
		SRS::EPP::Session::CmdQ->new();
	},
	handles => [qw( queue_command next_command
			add_command_response commands_queued
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

# this shouldn't be required... but is a good checklist
method check_queues() {
	$self->yield("send_pending_replies")
		if $self->response_ready;
	$self->yield("process_queue")
		if !$self->stalled and $self->commands_queued;
	$self->yield("process_responses")
		if $self->backend_response_ready;
	$self->yield("send_backend_queue")
		if $self->backend_pending;
}

# "stalling" means that no more processing can be advanced until the
# responses to the currently processing commands are available.
#
#  eg, "login" and "logout" both stall the queue, as will the
#  <transform><renew> command, if we have to first query the back-end
#  to determine what the correct renewal message is.
has stalled =>
	is => "rw",
	isa => "Bool",
	trigger => sub {
		my $self = shift;
		my $val = shift;
		$self->log_debug(
			"processing queue is ".($val?"":"un-")."stalled"
			);
		if ( !$val ) {
			$self->check_queues;
		}
	}
	;

method process_queue( Int $count = 1 ) {
	while ( $count-- > 0 ) {
		if ( $self->stalled ) {
			$self->state("Processing Command");
			$self->log_trace("stalled; not processing");
			last;
		}
		my $command = $self->next_command or last;
		$self->log_info(
			"processing command $command"
			);
		if ( $command->simple ) {
			# "simple" commands include "hello" and "logout"
			my $response = $command->process($self);
			$self->log_debug(
				"processed simple command $command; response is $response"
				);
			$self->add_command_response($response, $command);
		}
		elsif ( $command->authenticated xor $self->user ) {
			$self->add_command_response(
				$command->make_response(
					Error => code => 2001,
					),
				$command,
				);
			$self->log_info(
	"rejecting command: ".($self->user?"already":"not")." logged in"
				);
		}
		else {
			# regular message which may need to talk to the SRS backend
			my @messages = $command->process($self);

			# check what kind of messages these are
			if ( $messages[0]->does('XML::SRS::Action') or $messages[0]->does('XML::SRS::Query') ) {
				@messages = map {
					SRS::EPP::SRSRequest->new(
						message => $_,
						);
					} @messages;
				$self->log_info(
				"command produced ".@messages." SRS messages"
					);
				$self->queue_backend_request($command, @messages);
				if ( $command->isa("SRS::EPP::Command::Login") ) {
					$self->state("Processing <login>");
					#$self->stalled(1);
				}
				else {
					$self->state("Processing Command");
				}
				$self->yield("send_backend_queue");
			}
			elsif ( $messages[0]->isa('XML::EPP') ) {
				# add these messages to the outgoing queue
				@messages = map {
					SRS::EPP::EPPResponse->new(
						message => $_,
						);
				} @messages;

				# add to the queue
				$self->add_command_response($_, $command)
					for @messages;
			}
			else {
				# not sure what these are
				die "Really shouldn't be here\n";
			}
		}
		$self->yield("send_pending_replies")
			if $self->response_ready;
	}
}

#----
# method to say "we're connected, so send a greeting"; if this class
# were abstracted to not run over a stream transport then this would
# be important.
method connected() {
	$self->state("Prepare Greeting");
	my $response = SRS::EPP::Response::Greeting->new(
		session => $self,
		);
	$self->log_info(
	"prepared greeting $response for ".$self->peerhost
		);
	my $socket_fd = $self->io->get_fd;
	$self->log_trace("setting up io event handlers for FD $socket_fd");
	my $w = $self->event->io(
		desc => "input_event",
		fd => $socket_fd,
		poll => 'r',
		cb => sub {
			$self->log_trace("got input callback");
			$self->input_event;
		},
		timeout => 120,
		timeout_cb => sub {
			$self->log_trace("got input timeout event");
			$self->input_timeout;
		},
		);
	$self->input_event_watcher($w);

	$w = $self->event->io(
		desc => "output_event",
		fd => $socket_fd,
		poll => 'w',
		cb => sub {
			$self->output_event;
		},
		timeout => 120,
		timeout_cb => sub {
			$self->log_trace("got output timeout event");
		},
		);
	$w->stop;
	$self->output_event_watcher($w);

	$self->send_reply($response);
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
	lazy => 1,
	default => sub {
		my $self = shift;
		my $ua = SRS::EPP::Proxy::UA->new(session => $self);
		$self->log_trace("setting up UA input event");
		my $w;
		$w = $self->event->io(
			desc => "user_agent",
			fd => $ua->read_fh,
			poll => 'r',
			cb => sub {
				if ( $self->user_agent ) {
					$self->log_trace("UA input event fired, calling backend_response");
					$self->backend_response;
				}
				else {
					$self->log_trace("canceling UA watcher");
					$w->cancel;
				}
			},
			);
		$ua;
	},
	handles => {
		"user_agent_busy" => "busy",
	},
	;

has 'backend_url' =>
	isa => "Str",
	is => "rw",
	required => 1,
	;

has 'active_request' =>
	is => "rw",
	isa => "Maybe[SRS::EPP::SRSMessage]",
	;

method next_message() {
	my @next = $self->backend_next($self->backend_tx_max)
		or return;
	my $tx = XML::SRS::Request->new(
		version => "auto",
		requests => [ map { $_->message } @next ],
		);
	my $rq = SRS::EPP::SRSMessage->new(
		message => $tx,
		parts => \@next,
		);
	$self->log_info("creating a ".@next."-part SRS message");
	if ( $self->log->is_debug ) {
		$self->log_debug("parts: @next");
	}
	$self->active_request( $rq );
	$rq;
}

method send_backend_queue() {
	return if $self->user_agent_busy;

	my $tx = $self->next_message;
	my $xml = $tx->to_xml;
	$self->log_packet(
		"backend request",
		$xml,
		);
	my $sig = $self->openpgp->detached_sign($xml);
	$self->log_debug("signed XML message - sig is ".$sig)
		if $self->log->is_debug;
	my $reg_id = $self->user;
	if ( !$reg_id ) {
		$reg_id = $self->want_user;
	}

	my $req = POST(
		$self->backend_url,
		[
			r => $xml,
			s => $sig,
			n => $reg_id,
			],
		);
	$self->log_info(
		"posting to ".$self->backend_url." as registrar $reg_id"
		);

	$self->user_agent->request( $req );
}

sub url_decode {
	my $url_encoded = shift;
	$url_encoded =~ tr{+}{ };
	$url_encoded =~ s{%([0-9a-f]{2})}{chr(hex($1))}eg;
	return $url_encoded;
}

#----
# Dealing with backend responses
method backend_response() {
	my $response = $self->user_agent->get_response;

	# urldecode response; split response from fields
	my $content = $response->content;

	$self->log_debug(
		"received ".bytes::length($content)." bytes of "
			."response from back-end"
		);

	my %fields = map {
		my ($key, $value) = split "=", $_, 2;
		($key, decode("utf8", url_decode($value)));
	} split "&", $content;

	# check signature
	$self->log_debug("verifying signature");
	$self->openpgp->verify_detached($fields{r}, $fields{s})
		or die "failed to verify BE response integrity";

	# decode message
	$self->log_packet("BE response", $fields{r});
	my $message = XML::SRS::Response->parse($fields{r});
	my $rs_tx = SRS::EPP::SRSMessage->new( message => $message );

	$self->be_response($rs_tx);

	# user agent is now free, perhaps more messages are waiting
	$self->yield("send_backend_queue")
		if $self->backend_pending;
}

method be_response( SRS::EPP::SRSMessage $rs_tx ) {
	my $request = $self->active_request;
	#$self->active_request(undef);
	my $rq_parts = $request->parts;
	my $rs_parts = $rs_tx->parts;
	$self->log_debug(
		"response from back-end has ".@$rs_parts." parts, "
			."active request ".@$rq_parts." parts"
		);
	if ( @$rs_parts < @$rq_parts and @$rs_parts == 1 and
		     $rs_parts->[0]->message->isa("XML::SRS::Error")
	     ) {
		# this is a more fundamental type of error than others
		# ... 'extend' to the other messages
		@$rs_parts = ((@$rs_parts) x @$rq_parts);
	}
	(@$rq_parts == @$rs_parts) or do {
		die "rs parts != rq parts";
	};

	for (my $i = 0; $i <= $#$rq_parts; $i++ ) {
		$self->add_backend_response($rq_parts->[$i], $rs_parts->[$i]);
	}
	$self->yield("process_responses");
}

method process_responses() {
	while ( $self->backend_response_ready ) {
		my ($cmd, @rs) = $self->dequeue_backend_response;
		$self->log_info("notifying command $cmd of back-end response");
		my $resp = $cmd->notify(@rs);
		if ( $resp->isa("SRS::EPP::Response") ) {
			$self->log_info( "command $cmd is complete" );
			$self->state("Prepare Response");
			$self->log_debug( "response to $cmd is response $resp" );
			$self->add_command_response($resp, $cmd);
			$self->yield("send_pending_replies")
				if $self->response_ready;
		}
		elsif ( $resp->isa("XML::SRS") ) {
			$self->log_info( "command $cmd not yet complete" );
			my @messages = map {
				SRS::EPP::SRSRequest->new(
					message => $_,
					);
			} $resp;
			$self->log_info(
				"command $cmd produced ".@messages." further SRS messages"
				);
			$self->queue_backend_request($cmd, @messages);
			$self->yield("send_backend_queue");
		}
	}
}

method send_pending_replies() {
	while ( $self->response_ready ) {
		my $response = $self->dequeue_response;
		$self->log_info(
			"queuing response $response"
			);
		$self->send_reply($response);
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

method send_reply( SRS::EPP::Response $rs ) {
	$self->log_debug(
		"converting response $rs to XML"
		);
	my $reply_data = $rs->to_xml;
	$self->log_packet("output", $reply_data);
	if ( utf8::is_utf8($reply_data) ) {
		$reply_data = encode("utf8", $reply_data);
	}
	$self->log_info(
		"response $rs is ".bytes::length($reply_data)
			." bytes long"
		);
	my $length = pack("N", bytes::length($reply_data)+4);
	push @{ $self->output_queue }, $length, $reply_data;
	$self->yield("output_event");
	my $remaining = 0;
	for ( @{ $self->output_queue }) {
		$remaining += bytes::length;
	}
	return $remaining;
}

# once we are "shutdown", no new commands will be allowed to process
# (stalled queue) and the connection will be disconnected once the
# back-end processing and output queue is cleared.
has 'shutting_down' =>
	is => "rw",
	isa => "Bool",
	;
method shutdown() {
	$self->log_info( "shutting down session" );
	$self->state("Shutting down");
	$self->stalled(1);
	$self->shutting_down(1);
	$self->yield("output_event");
}

method input_timeout() {
	# just hang up...
	$self->shutdown;
}

method do_close() {
	# hang up on us without logging out will you?  Well, we'll
	# just have to close your TCP session without properly closing
	# SSL.  Take that.
	$self->log_debug( "shutting down Socket" );
	$self->socket->shutdown(1);
	$self->log_debug( "shutting down user agent" );
	$self->user_agent(undef);
	$self->input_event_watcher->cancel;
	$self->event->unloop_all;
}

# called when input_event fires, but nothing is readable.
method empty_read() {
	$self->log_info( "detected EOF on input" );
	$self->do_close;
}

method output_event() {
	my $oq = $self->output_queue;
	my $written = 0;
	my $io = $self->io;
	while ( @$oq ) {
		my $datum = shift @$oq;
		my $wrote = $io->write( $datum );
		if ( $wrote <= 0 ) {
			$self->log_debug("error on write? \$! = $!");
			unshift @$oq, $datum;
			last;
		}
		else {
			$written += $wrote;  # thankfully, this is returned in bytes.
			if ( $wrote < bytes::length $datum ) {
				unshift @$oq, bytes::substr $datum, $wrote;
				last;
			}
		}
	}
	$self->log_trace(
	"output_event wrote $written bytes, ".@$oq." chunk(s) remaining"
		);
	if ( @$oq ) {
		$self->output_event_watcher->start;
	}
	else {
		$self->output_event_watcher->stop;
		$self->log_info("flushed output to client");
		if ( $self->shutting_down ) {
			$self->check_queues;
			# if check_queues didn't yield any events, we're done.
			if ( !keys %{$self->yielding} ) {
				$self->do_close;
			}
			else {
				$self->log_debug(
			"shutdown still pending: @{[keys %{$self->yielding}]}"
					);
			}
		}
	}
	return $written;
}

method log_packet(Str $label, Str $data) {
	$data =~ s{([\0-\037])}{chr(ord($1)+0x2400)}eg;
	$data =~ s{([,\|])}{chr(ord($1)+0xff00-0x20)}eg;
	my @data;
	while ( length $data ) {
		push @data, substr $data, 0, 1024, "";
	}
	for (my $i = 0; $i <= $#data; $i++ ) {
		my $n_of_n = (@data > 1 ? " [".($i+1)." of ".@data."]" : "");
		$self->log_info(
			"$label message$n_of_n: "
				.encode("utf8", $data[$i]),
			);
	}
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
 $session->send_reply($response);
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
client, each response its own SSL frame.  See L</send_reply>

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

=head2 send_pending_replies()

This is called by process_queue() or be_response(), and checks each
command for a corresponding L<SRS::EPP::Response> object, dequeues and
starts to send them back.

=head2 send_reply($response)

This is called by send_pending_replies(), and converts a
L<SRS::EPP::Response> object to network form, then starts to send it.
Returns the total number of octets which are currently outstanding; if
this is non-zero, the caller is expected to watch the output socket
for writability and call L<output_event()> once it is writable.

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

