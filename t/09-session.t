#!/usr/bin/perl -w
#
# test the SRS::EPP::Session class overall

use 5.010;
use strict;
use Test::More qw(no_plan);
use Fatal qw(:void open);

use XML::EPP;
use XML::EPP::Host;
use XML::SRS;

use t::Log4test;

BEGIN { use_ok("SRS::EPP::Session"); }

{
	package Mock::Base;
	sub isa { 1 }
	sub AUTOLOAD {
		our $AUTOLOAD =~ m{.*::(.+)};
		my $self = shift;
		if ( @_ ) {
			$self->{$1} = shift;
		} else {
			$self->{$1};
		}
	}
	sub new {
		my $class = shift;
		bless { @_ }, $class;
	}
}

{
	package Mock::Event::Watcher;
	our @ISA = qw(Mock::Base);
	sub stop {
		my $self = shift;
		$self->{running} = 0;
	};
	sub start {
		my $self = shift;
		$self->{running} = 1;
	};
	sub ready {
		my $self = shift;
		if ( $self->{running}//=1 ) {
			if ( $self->{poll} eq "r" ) {
				if ( length ${ $self->{fd}||\"" }) {
					return 1;
				}
			}
			else {
				1;
			}
		}
	}
}

{
	package Mock::Event;
	our @ISA = qw(Mock::Base);
	for my $func ( qw(io timer) ) {
		no strict 'refs';
		*$func = sub {
			my $self = shift;
			if ( @_ ) {
				push @{$self->{$func}}, {@_};
				my $w = Mock::Event::Watcher->new
					(event => $self,
					 @_);
				$self->{watchers}{$w}=$w
					if $func eq "io";
				return $w;
			}
			else {
				$self->{$func};
			}
		};
	}
	sub queued_events {
		my $self = shift;
		my $events = $self->{timer}
			or return();
		map { my $href = ref $_ eq "HASH" ? $_ : { @$_ };
		      $href->{desc} } @$events;
	}
	sub has_queued_events {
		my $self = shift;
		$self->timer && @{ $self->timer };
	}
	sub queued {
		my $self = shift;
		my $event = shift;
		grep { $_ eq $event } $self->queued_events;
	}
	sub ignore {
		my $self = shift;
		my $event = shift;
		my $events = $self->{timer} or return;
		@$events = grep { $_->{desc} ne $event }
			@$events;
	}
	sub loop_until {
		my $self = shift;
		my $end = shift;
		my $allowed = shift if ref $_[0];
		my $test_name = pop;
		$test_name ||= "event loop";
		my $fail;
		while ( !$end->() ) {
			my $event;
			$event = shift @{ $self->{timer}||=[] }
				or do {
					for my $watcher (values %{$self->{watchers}}) {
						if ( $watcher->ready ) {
							$event = $watcher;
							last;
						}
					}
				};
			last if !$event;
			my $desc = $event->{desc};
			my $cb = $event->{cb};
			if ( $allowed and
				     !($desc ~~ @$allowed) ) {
				# Hoist the main::fail!!
				main::fail("$test_name - "
					   ."illegal event '$desc' "
					   ."(allowed: @$allowed)");
				++$fail;
				last;
			}
			else {
				$cb->();
			}
		}
		main::pass("$test_name - events as expected")
				unless $fail;
	}
}

{
	package Mock::IO;
	use Encode;
	use utf8;
	use bytes qw();
	our @ISA = qw(Mock::Base);
	our @model_fds = qw(5 8 4 7);
	sub new {
		my $class = shift;
		my $self = $class->SUPER::new(@_);
		$self->{get_fd} = shift @model_fds;
		$self;
	}
	sub get_fd {
		my $self = shift;
		\$self->{input};
	}
	use bytes;
	sub read {
		my $self = shift;
		my $how_much = shift;
		bytes::substr $self->{input}, 0, $how_much, "";
	}
	sub peek {
		my $self = shift;
		my $how_much = shift;
		bytes::substr $self->{input}, 0, $how_much;
	}
	our $been_evil;
	sub write {
		my $self = shift;
		my $data = shift;
		my $how_much = bytes::length($data);
		if ( rand(1) < 0.5 ) {
			# be EEEVIL and split string in the middle of
			# a utf8 sequence if we can... hyuk yuk yuk
			$data = Encode::encode("utf8", $data)
				if utf8::is_utf8($data);
			if ( $data =~ /^(.*?[\200-\377])/ and !$been_evil ) {
				print STDERR "BEING DELIGHTFULLY EVIL\n";
				$how_much = bytes::length($1);
				$been_evil++;
			}
			else {
				$how_much = int($how_much * rand(1));
			}
		}
		$self->{output}//="";
		$self->{output} .= bytes::substr($data, 0, $how_much);
		return $how_much;
	}
	sub get_packet {
		my $self = shift;
		my $output = $self->{output};
		my $packet_length = unpack
			("N", bytes::substr($output, 0, 4));
		$packet_length or return;
		my $packet = bytes::substr($output, 4, $packet_length - 4);
		if ( bytes::length($packet)+4 == $packet_length ) {
			bytes::substr($self->{output}, 0, $packet_length, "");
		}
		else {
			return;
		}
		return XML::EPP->parse($packet);
	}
}

my $input = do {
	(my $filename = $0) =~ s{\.t}{/example-session.raw};
	open my $input, "<$filename";
	local($/);
	<$input>
};

my $event = Mock::Event->new();
my $session = SRS::EPP::Session->new(
	backend_url => "foo",
	event => $event,
	io => Mock::IO->new(input => ""),
	peerhost => "101.1.5.27",
	socket => Mock::Base->new,
	peer_cn => "foobar.client.cert.example.com",
       );

# 0. test the ->connected event and greeting response
$session->connected;
is(@{$session->{event}{io}}, 2, "set up IO watchers OK on connected");
is_deeply(
	[$session->event->queued_events], ["output_event"],
	"data waiting to be written",
       );

# let's write to the socket for a bit, until we see an event.  This
# simulates events from Event etc saying that the output socket is
# writable, and the condition where variable-sized chunks can be
# written to it.
srand 107;
$event->loop_until(
	sub { !@{ $session->output_queue } },
	[ qw(output_event) ],
	"queued output",
       );

my $greeting = delete $session->io->{output};
my $greeting_length = unpack("N", bytes::substr($greeting, 0, 4, ""));
is(bytes::length($greeting)+4, $greeting_length,
   "got a full packet back ($greeting_length bytes)");

is_deeply(
	[$session->event->queued_events], [ ],
	"After issuing greeting, no events waiting"
       );
is($session->state, "Waiting for Client Authentication",
   "RFC5730 session state flowchart state as expected");

# 1. test that input leads to queued commands
$session->{io}{input} = $input;
$event->loop_until(
	sub { $session->event->queued("process_queue") or
		      !$session->io->input },
	[qw(input_event)],
	"queued input",
	);

is($session->commands_queued, 1, "command is now queued");

# 2. proceed with the event which was 'queued'
$event->loop_until(
	sub { $event->queued("output_event") },
	[qw(process_queue input_event send_pending_replies)],
	"queue processing",
	);

# this one can jump the queue here...
my $error;
do {
	$session->output_event;
} until ( $error = $session->io->get_packet );

# 3. check that we got an error!
use utf8;
like($error->message->result->[0]->msg->content,
     qr/Command syntax error/i,
     "got an appropriate error");
is($error->message->tx_id->client_id,
   "ÄBC-12345", "returned client ID OK");

# 4. check that the login message results in queued back-end messages
$event->loop_until(
	sub {
		$event->queued("send_backend_queue");
	},
	[qw(input_event process_queue output_event)],
	"login produces a backend message",
	);

ok($session->backend_pending,
   "login message produced backend messages");
ok($session->stalled,
   "waiting for login result before processing further commands");
my $rq = $session->next_message;
is(@{$rq->parts}, 3, "login makes 3 messages");
is_deeply(
	[ map { $_->message->root_element } @{$rq->parts} ],
	[ qw(RegistrarDetailsQry AccessControlListQry
	     AccessControlListQry) ],
	"login message transform",
       );

ok($event->queued("send_backend_queue"), "Session wants to send", );

use Crypt::Password;

# fake some responses.
$event->ignore("send_backend_queue");

# these objects are missing fields and would not serialize; but for
# this test it doesn't matter.  We must only provide the attributes
# marked "required"
my @action_rs = (
	XML::SRS::Registrar->new(
		id => "123",
		name => "Model Registrar",
		account_reference => "xx",
		epp_auth => password("foo-BAR2"),
	       ),
	XML::SRS::ACL->new(
		Resource => "epp_connect",
		List => "allow",
		Size => 1,
		Type => "registrar_ip",
		entries => [
			XML::SRS::ACL::Entry->new(
				Address => "101.1.5.0/24",
				RegistrarId => "90",
				Comment => "Test Registrar Netblock",
			       ),
		       ],
	       ),
	XML::SRS::ACL->new(
		Resource => "epp_client_certs",
		List => "allow",
		Size => 1,
		Type => "registrar_domain",
		entries => [
			XML::SRS::ACL::Entry->new(
				DomainName => "*.client.cert.example.com",
				RegistrarId => "90",
				Comment => "Test Registrar Key",
			       ),
		       ],
	       ),
       );

use MooseX::TimestampTZ;

my @rs = map {
	XML::SRS::Result->new(
		action => $_,
		fe_id => "2",
		unique_id => "1234",
		by_id => "123",
		server_time => timestamptz,
		response => shift(@action_rs),
	       )
	}
	map {
		$_->message->root_element
	}
	@{$rq->parts};

my $srs_rs = XML::SRS::Response->new(
	version => "auto",
	results => \@rs,
	RegistrarId => 90,
       );

my $rs_tx = SRS::EPP::SRSMessage->new( message => $srs_rs );
$session->be_response($rs_tx);

# now, with the response there, process_replies should be ready.
ok($event->queued("process_responses"),
   "Session wants to process that response",
  );

my $response;
$event->loop_until(
	sub { $response = $session->io->get_packet },
	[qw(send_pending_replies input_event process_queue
	    process_responses output_event)],
	"response produced",
       );

is($response->message->result->[0]->code, 1000, "Login successful!");

# now we should have a response ready to go
ok($session->user, "Session now authenticated");

$session->input_event;

# ... and we should eventually log out
my @expected = qw(process_queue send_pending_replies output_event);
my $failed = 0;
event:
while ( my @events = $session->event->queued_events ) {
	$session->input_event if $session->io->input;
	for my $event ( @events ) {
		unless ($event ~~ @expected) {
			fail("weren't expecting $event");
			$failed = 1;
			last event;
		}
		$session->$event;
	}
}
pass("events as expected") unless $failed;

my $goodbye = $session->io->get_packet;
is(eval{$goodbye->message->result->[0]->code}, 1500, "logout response");

# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Artistic License 2.0 for more details.
#
# You should have received a copy of the Artistic License the file
# COPYING.txt.  If not, see
# <http://www.perlfoundation.org/artistic_license_2_0>

