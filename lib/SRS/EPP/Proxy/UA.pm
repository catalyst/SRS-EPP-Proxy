
package SRS::EPP::Proxy::UA;

use Moose;
use MooseX::Method::Signatures;
use LWP::UserAgent;
use Net::SSLeay::OO;
use Moose::Util::TypeConstraints;
use IO::Handle;
use Storable qw(store_fd retrieve_fd);

enum __PACKAGE__."::states" => qw(waiting busy ready);
BEGIN {
	class_type "HTTP::Request";
	class_type "HTTP::Response";
	class_type "IO::Handle";
}

has 'write_fh' =>
	is => "rw",
	isa => "IO::Handle|GlobRef",
	;

has 'read_fh' =>
	is => "rw",
	isa => "IO::Handle|GlobRef",
	;

has 'pid' =>
	is => "rw",
	isa => "Int",
	;

has 'state' =>
	is => "rw",
	isa => __PACKAGE__."::states",
	default => "waiting",
	;

method busy() {
	$self->state eq "busy";
}

method ready() {
	if ( $self->busy ) {
		$self->check_reader_ready;
	}
	$self->state eq "ready";
}
method waiting() {
	$self->state eq "waiting";
}

method check_reader_ready( Num $timeout = 0 ) {
	my $fh = $self->read_fh;
	my $rin = '';
	vec($rin, fileno($fh), 1) = 1;
	my $win = '';
	my $ein = $rin;
	my ($nfound) = select($rin, $win, $ein, $timeout);
	if ( $nfound ) {
		if ( vec($ein, fileno($fh), 1) ) {
			die "reader handle in error state";
		}
		elsif ( vec($rin, fileno($fh), 1) ) {
			$self->state("ready");
			return 1;
		}
		else {
			die "??";
		}
	}
	else {
		return;
	}
}

sub BUILD {
	my $self = shift;
	{
		pipe(my $rq_rdr, my $rq_wtr);
		pipe(my $rs_rdr, my $rs_wtr);
		my $pid = fork;
		defined $pid or die "fork failed; $!";
		if ( $pid ) {
			$self->pid($pid);
			$self->read_fh($rs_rdr);
			$self->write_fh($rq_wtr);
			return;
		}
		else {
			$self->read_fh($rq_rdr);
			$self->write_fh($rs_wtr);
		}
	}
	$self->loop;
}

sub DESTROY {
	my $self = shift;
	if (my $pid = $self->pid) {
		kill 15, $pid;
		waitpid($pid,0);
	}
}

use Storable qw(fd_retrieve store_fd);

has 'ua' =>
	is => "ro",
	isa => "LWP::UserAgent",
	lazy => 1,
	default => sub {
		LWP::UserAgent->new(
			agent => __PACKAGE__,
			timeout => 30,  # 'fast' timeout for EPP sessions
		       )
	};

method loop() {
	$SIG{TERM} = sub { exit(0) };
	while ( 1 ) {
		my $request = eval { fd_retrieve($self->read_fh) }
			or do {
				last;
			};
		my $response = $self->ua->request($request);
		store_fd $response, $self->write_fh;
		$self->write_fh->flush;
	}
	exit(0);
}

method request( HTTP::Request $request ) {
	die "sorry, can't handle a request in state '".$self->state."'"
		unless $self->waiting;
	store_fd $request, $self->write_fh;
	$self->write_fh->flush;
	$self->state("busy");
}

method get_response() {
	die "sorry, not ready yet" unless $self->ready;
	my $response = retrieve_fd($self->read_fh);
	$self->state("waiting");
	return $response;
}

1;

__END__

=head1 NAME

SRS::EPP::Proxy::UA - subprocess-based UserAgent

=head1 SYNOPSIS

 my $ua = SRS::EPP::Proxy::UA->new;   # creates sub-process.

 $ua->request($req);          # off it goes!
 print "yes" if $ua->busy;    # it's busy!
 sleep 1 until $ua->ready;    # do other stuff
 my $response = $ua->get_response;
 print "yes" if $ua->waiting; # it's waiting for you!

=head1 DESCRIPTION

This class provides non-blocking UserAgent behaviour, by using a slave
sub-process to call all the blocking L<LWP::UserAgent> functions to do
the retrieval.

This is done because the L<SRS::EPP::Session> class is designed to be
a non-blocking system.

=head1 SEE ALSO

L<LWP::UserAgent>, L<SRS::EPP::Session>

=head1 AUTHOR AND LICENCE

Development commissioned by NZ Registry Services, and carried out by
Catalyst IT - L<http://www.catalyst.net.nz/>

Copyright 2009, 2010, NZ Registry Services.  This module is licensed
under the Artistic License v2.0, which permits relicensing under other
Free Software licenses.

=cut
