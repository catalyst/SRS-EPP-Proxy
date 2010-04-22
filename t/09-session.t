#!/usr/bin/perl -w
#
# test the SRS::EPP::Session class overall

use strict;
use Test::More qw(no_plan);
use Fatal qw(:void open);

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
}

{
	package Mock::IO;
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
		substr $self->{input}, 0, $how_much, "";
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

# 0. fixme - should test the ->connected event

# 1. test that input leads to queued commands
do {
	$session->input_event;
} until ( $session->{event}->timer or !$session->{io}->input );

my %event = @{ shift @{$session->{event}{timer}} };
is($event{desc}, "process_queue", "Got the right event out!");
is($session->commands_queued, 1, "command is now queued");

# 2. proceed with the event which was 'queued'
$session->process_queue(1);

# 3. check that we got an error!



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

