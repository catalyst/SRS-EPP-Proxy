
package SRS::EPP::Proxy::Listener;

use 5.010;  # for (| alternation feature

use Moose;
use MooseX::Method::Signatures;

use IO::Select;

our $SOCKET_TYPE;
BEGIN {
	my $sock = eval {
		require IO::Socket::INET6;
		IO::Socket::INET6->new(
			Listen    => 1,
			LocalAddr => '::1',
			LocalPort => int(rand(60000)+1024),
			Proto     => 'tcp',
		       );
	};
	if ( $sock or $!{EADDRINUSE} ) {
		$SOCKET_TYPE = "IO::Socket::INET6";
	}
	else {
		$SOCKET_TYPE = "IO::Socket::INET";
		require IO::Socket::INET;
	}
}

has 'listen' =>
	is => "ro",
	isa => "ArrayRef[Str]",
	required => 1,
	default => sub { [ $SOCKET_TYPE =~ /6/ ? "[::]" : "0.0.0.0" ] },
	;

has 'sockets' =>
	is => "ro",
	isa => "ArrayRef[IO::Socket]",
	default => sub { [] },
	;

use constant EPP_DEFAULT_TCP_PORT => 700;
use constant EPP_DEFAULT_LOCAL_PORT => "epp(".EPP_DEFAULT_TCP_PORT.")";

method init_listener() {

	my @sockets;
	for my $addr ( @{ $self->listen } ) {

		# parse out the hostname and port; I can't see another
		# way to supply a default port number.
		my ($hostname, $port) = $addr =~
			m{^(|\[([^]]+)\]|([^:]+))(?::(\d+))?$}
				or die "bad listen address: $addr";
		$port ||= EPP_DEFAULT_LOCAL_PORT;

		my $socket = $SOCKET_TYPE->new(
			Listen => 5,
			LocalAddr => $hostname,
			LocalPort => $port,
			Proto => "tcp",
			ReuseAddr => 1,
		       );

		if ( !$socket ) {
			warn "Failed to listen on $hostname:$port; $!";
		}

		push @sockets, $socket;
	}

	if ( !@sockets ) {
		die "No listening sockets; aborting";
	}

	@{ $self->sockets } = @sockets;
}

method accept( Int $timeout? ) {
	my $select = IO::Select->new();
	$select->add($_) for @{$self->sockets};
	my @ready = $select->can_read( $timeout )
		or return;
	while ( @ready > 1 ) {
		if ( rand(1) > 0.5 ) {
			shift @ready;
		}
		else {
			pop @ready;
		}
	}
	$ready[0]->accept;
}

1;

__END__

=head1 NAME

SRS::EPP::Proxy::Listener - socket factory class

=head1 SYNOPSIS

 my $listener = SRS::EPP::Proxy::Listener->new(
     listen => [ "hostname:port", "address:port" ],
     );

 # this does the listen part
 $listener->init_listener;

 # this normally blocks, and returns a socket.
 # it might return undef, if you pass it a timeout.
 my $socket = $listener->accept;

=head1 DESCRIPTION

This class is a TCP/IP listener.  It listens on the configured ports
for TCP connections and returns sockets when there are incoming
connections waiting.

You don't actually need to supply the port or listen addresses; the
defaults are to listen on INADDR_ANY (0.0.0.0) or IN6ADDR_ANY (::) on
port epp(700).

If the L<IO::Socket::INET6> module is installed, then the module tries
to listen on a random port on the IPv6 loopback address on start-up.
If that works, then IPv6 is preferred over IPv4 from then on.  IPv6
addresses (not names) must be passed in square brackets, such as
C<[2404:130:0::42]>.

In general these rules should make this listener behave like any
normal IPv6-aware daemon.

=cut
