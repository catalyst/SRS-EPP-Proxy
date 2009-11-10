# vim: filetype=perl:noexpandtab:ts=3:sw=3
#
# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

package SRS::EPP::Session;

use Moose;

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
 $session->queue_response($response);
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
read on the input socket.

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

