#!/usr/bin/perl -w
#
# test the SRS::EPP::Session class overall

use 5.010;
use strict;
use Test::More qw(no_plan);
use Fatal qw(:void open);
use Data::Dumper;

use XML::EPP;
use XML::EPP::Host;

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
	package Mock::Event;
	our @ISA = qw(Mock::Base);
	for my $func ( qw(io timer) ) {
		no strict 'refs';
		*$func = sub {
			my $self = shift;
			if ( @_ ) {
				my $aref=$self->{$func}||=[];
				push @$aref,\@_;
			}
			else {
				$self->{$func};
			}
		};
	}
	sub queued_events {
		my $self = shift;
		my $events = delete $self->{timer}
			or return();
		map { my $href = ref $_ eq "HASH" ? $_ : { @$_ };
		      $href->{desc} } @$events;
	}
	sub has_queued_events {
		my $self = shift;
		$self->timer && @{ $self->timer };
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
	use bytes;
	sub read {
		my $self = shift;
		my $how_much = shift;
		bytes::substr $self->{input}, 0, $how_much, "";
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
		my $packet = bytes::substr($output, 4, $packet_length - 4);
		if ( bytes::length($packet)+4 == $packet_length ) {
			bytes::substr($self->{output}, 0, $packet_length, "");
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

my $session = SRS::EPP::Session->new(
	event => Mock::Event->new(),
	io => Mock::IO->new(input => $input),
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
srand 42;
do {
	$session->output_event;
} while ( @{ $session->output_queue } );

my $greeting = delete $session->io->{output};
my $greeting_length = unpack("N", bytes::substr($greeting, 0, 4, ""));
is(bytes::length($greeting)+4, $greeting_length,
   "got a full packet back ($greeting_length bytes)");
#diag($greeting);

is_deeply(
	[$session->event->queued_events], [],
	"After issuing greeting, no events ready"
       );
is($session->state, "Waiting for Client Authentication",
   "RFC5730 session state flowchart state as expected");

# 1. test that input leads to queued commands
do {
	$session->input_event;
} until ( $session->event->has_queued_events or !$session->io->input );

is_deeply(
	[$session->event->queued_events], ["process_queue"],
	"A valid input message results in a queued output event",
       )
	or diag Dumper($session);
is($session->commands_queued, 1, "command is now queued");

# test that the string is valid

$session->process_queue;

# 2. proceed with the event which was 'queued'
my @expected = qw(process_queue send_pending_replies output_event);
my $failed = 0;
event:
while ( $session->io->input ) {
	my @events = $session->event->queued_events
		or last;
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

# 3. check that we got an error!
do {
	$session->output_event;
} while ( @{ $session->output_queue } );

my $error = $session->io->get_packet;

use utf8;
like($error->message->result->[0]->msg->content,
     qr/not logged in/i,
     "got an appropriate error");
is($error->message->tx_id->client_id,
   "ÄBC-12345", "returned client ID OK");

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

