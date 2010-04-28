#
# Copyright (C) 2009, 2010  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

package SRS::EPP::Proxy;

use MooseX::Singleton;
use MooseX::Method::Signatures;

use SRS::EPP::Session;

use Log::Log4perl qw(:easy);

use POSIX ":sys_wait_h";

with 'MooseX::SimpleConfig';
with 'MooseX::Getopt';
with 'MooseX::Log::Log4Perl';
with 'MooseX::Daemonize';

has '+configfile' => (
	default => sub { [
		"$ENV{HOME}/.srs_epp_proxy.yaml",
		'/etc/srs-epp-proxy.yaml'
	       ] });

sub BUILD {
	my $self = shift;

	# should have already done SimpleConfig; with a bit of luck,
	# all properties in this master object may be specified there.

	# pass configuration via this method to log4perl
	my $logging = $self->logging;

	if ( !defined $logging ) {
		$logging = "info";
	}

	if ( !ref $logging and ! -f $logging ) {
		# 'default'
		if ( $self->is_daemon ) {
			$logging = {
		rootLogger => "$logging, Syslog",
		"appender.Syslog" => "Log::Log4perl::JavaMap::SyslogAppender",
		"appender.Syslog.logopt" => "pid",
		"appender.Syslog.Facility" => "daemon",
			};
		}
		else {
			$logging = {
		rootLogger => "$logging, Screen",
		"appender.Screen" => "Log::Log4perl::Appender::Screen",
		"appender.Screen.stderr" => 1,
			};
		}
	}

	# prepend "log4perl." to config hashes
	if ( ref $logging and ref $logging eq "HASH" ) {
		for my $key ( keys %$logging ) {
			if ( $key !~ /^log4perl\./ and
				     !exists $logging->{"log4perl.$key"}
				    ) {
				$logging->{"log4perl.$key"} =
					delete $logging->{$key};
			}
		}
	}

	Log::Log4Perl->init( $logging );
	# pass configuration options to the session class?
}

our $VERSION = "0.00_01";

has 'logging' =>
	is => "ro",
	isa => "HashRef[Str]",
	;

has 'listen' =>
	is => "ro",
	isa => "ArrayRef[Str]",
	;

has 'listener' =>
	is => "rw",
	isa => "SRS::EPP::Proxy::Listener",
	default => sub {
		require SRS::EPP::Proxy::Listener;
		my $self = shift;
		SRS::EPP::Proxy::Listener->new( listen => $self->listen );
	},
	lazy => 1,
	handles => {
		'init_listener' => 'init',
	},
	;

has 'ssl_key_file' =>
	is => "ro",
	isa => "Str",
	;

has 'ssl_cert_file' =>
	is => "ro",
	isa => "Str",
	;

has 'ssl_cert_dir' =>
	is => "ro",
	isa => "Str",
	;

use Sys::Hostname qw(hostname);
has 'server_name' =>
	is => "ro",
	isa => "Str",
	lazy => 1,
	default => sub {
		my $self = shift;
		my @listen = @{ $self->listen };
		if ( @listen == 1 and $listen[0] !~ /^(?:\d+\.|\[)/ ) {
			# listen address seems a reasonable default...
			$listen[0];
		}
		else {
			hostname;
		}
	};

has 'ssl_engine' =>
	is => "rw",
	isa => "Net::SSLeay::OO::Context",
	;

use Net::SSLeay::OO;
use Net::SSLeay::OO::Constants qw(MODE_ENABLE_PARTIAL_WRITE
				  MODE_ACCEPT_MOVING_WRITE_BUFFER
				  OP_ALL OP_NO_SSLv2 VERIFY_PEER
				  VERIFY_FAIL_IF_NO_PEER_CERT);

method init_ssl() {
	require Net::SSLeay::OO;
	my $ctx = Net::SSLeay::OO::Context->new;
	Net::SSLeay::OO::Constants->import(":all");
	$ctx->set_options(&OP_ALL | OP_NO_SSLv2);
	$ctx->set_verify(VERIFY_PEER | VERIFY_FAIL_IF_NO_PEER_CERT);
	$ctx->load_verify_locations("", $self->ssl_cert_dir);
	$ctx->use_PrivateKey_file($self->ssl_key_file);
	$ctx->use_certificate_chain_file($self->ssl_cert_file);
	$self->ssl_engine($ctx);
}

method init() {
	$self->init_pgp;
	$self->init_ssl;
	$self->init_listener;
}

has 'openpgp' =>
	is => "ro",
	isa => "SRS::EPP::OpenPGP",
	default => sub {
		my $self = shift;
		require SRS::EPP::OpenPGP;
		my $pgp_dir = $self->pgp_dir;
		my $secring_file = "$pgp_dir/secring.gpg";
		my $pubring_file = "$pgp_dir/pubring.gpg";
		my $pgp = SRS::EPP::OpenPGP->new(
			public_keyring => $pubring_file,
			secret_keyring => $pubring_file,
		       );
		$pgp->uid($self->pgp_keyid);
		$pgp;
	},
	handles => ["pgp"],
	;

has 'pgp_keyid' =>
	is => "ro",
	isa => "Str",
	;

has 'pgp_dir' =>
	is => "ro",
	isa => "Str",
	default => sub {
		$ENV{GNUPGHOME} || "$ENV{HOME}/.gnupg";
	},
	;

method init_pgp() {
	$self->pgp;
}

has 'forking' =>
	is => "ro",
	isa => "Bool",
	default => 0,
	;

has 'running' =>
	is => "rw",
	isa => "Bool",
	default => 1,
	;

has 'child_pids' =>
	is => "ro",
	isa => "ArrayRef[Int]",
	default => sub { [] },
	;

has 'backend' =>
	is => "ro",
	isa => "Str",
	default => "https://srstest.srs.net.nz/srs/registrar",
	;

method accept_one() {
	my $socket = $self->listener->accept
		or return;

	if ( $self->forking and (my $pid = fork) ) {
		push @{ $self->child_pids }, $pid;
	}
	else {
		# blocking SSL accept...
		my $ssl = $self->ssl_engine->accept($socket);

		# then set the socket to non-blocking for event-driven
		# fun.
		my $mode = ( MODE_ENABLE_PARTIAL_WRITE |
				     MODE_ACCEPT_MOVING_WRITE_BUFFER );
		$ssl->set_mode($mode);
		$socket->blocking(0);

		# create a new session...
		my $session = SRS::EPP::Session->new(
			io => $ssl,
		       );

		# let it know it's connected.
		$session->connected;

		return $session;
	}
}

method signals =>
	is => "rw",
	isa => "ArrayRef[Int]",
	default => sub { [(0) x 15] },
	;

method handlers =>
	is => "rw",
	isa => "HashRef[CodeRef]",
	default => sub { {} },
	;

method signal_handler( Int $signal ) {
	$self->signals[$signal]++;
}

method process_signals() {
	my @sig_a = $self->signals->[$signal];
	while (my ($signal,$handler) = each %{ $self->handlers }) {
		if ($sig_a[$signal]) {
			$sig_a[$signal] = 0;
			$handler->();
		}
	}
}

method catch_signal(Str $sig, CodeRef $sub) {
	$SIG{$sig} = sub { $self->signal_handler($sig) };
}

method accept_loop() {
	$self->catch_signal(TERM => sub { $self->running(0) });
	if ( $self->forking ) {
		$self->catch_signal(CHLD => sub { $self->reap_children });
	}
	while ( $self->running ) {
		my $session = $self->accept_one;
		if ( $session ) {
			$session->loop;
			exit if $self->forking;
		}
		else {
			my $peerhost = $socket->peerhost;
			my $ssl = $self->ssl_engine->accept($socket);
			my $client_cert = $ssl->get_peer_certificate;
			my $peer_cn = $client_cert->get_subject_name;
			my $mode = ( MODE_ENABLE_PARTIAL_WRITE |
					     MODE_ACCEPT_MOVING_WRITE_BUFFER );
			$socket->blocking(0);
			my $session = SRS::EPP::Session->new(
				io => $ssl,
				event => "Event",
				peerhost => $peerhost,
				peer_cn => $peer_cn,
			       );
			$session->connected;
			Event->loop;
			exit(0);
		}
	}
}

method reap_children() {
	my $self = shift;
	my $kid;
	my %reaped;
	do {
		$kid = waitpid(-1, WNOHANG);
		if ($kid > 0) {
			$reaped{$kid} = $?
			redo;
		}
	} while 0;
	my $child_pids = $self->child_pids;
	@$child_pids = grep { exists $reaped{$_} } @$child_pids;
}

method make_events(SRS::EPP::Session $session) {
	

}

1;

__END__

=head1 NAME

SRS::EPP::Proxy - IETF EPP <=> SRS XML proxy software

=head1 SYNOPSIS

 my $proxy = SRS::EPP::Proxy->new(

     # where to listen for inbound connections
     listen => [ "$addr:$port", "[$addr6]:$port" ],

     # SSL engine: certificate for presentation
     ssl_key_file => $ssl_key_filename,
     ssl_cert_file => $ssl_key_filename,

     # path for verifying client certificates
     ssl_cert_dir => $ssl_cert_path,
     # and of course, revocations
     ssl_crl_file => $ssl_crl_file,

     # PGP home for dealing with the SRS
     pgp_dir => $path,

     );

 # initialises everything - listens on sockets, checks SSL
 # keys and PGP home dir valid
 $proxy->init();

 # main entry mechanism
 $proxy->accept_loop();

 # alternate piecemeal interfaces, mostly for testing
 $proxy->init_listener;
 $proxy->init_ssl;
 $proxy->init_pgp;
 my $session = $proxy->accept_one;  # doesn't fork

=head1 DESCRIPTION

SRS::EPP::Proxy implements an XML to XML gateway between two
contemporary protocols for domain name management; EPP as defined by
RFC 3730 and later, and the SRS protocol used by the .nz registry.

This module implements the SSL listener; it accepts connections, forks
a new child for each one, collects client certificate information
about the SSL connection as recommended by RFC 3734, and then starts
an Event loop (using L<Event>) and passes control to the
L<SRS::EPP::Session> module.

Other modules of interest; ie the key modules in this stack are:

=over

=item L<Moose>

Almost every module on this list is written using L<Moose>.

=item L<SRS::EPP::Session>

Implements the session logic which manages connections, and "oversees"
the general flow of converting incoming messages to messages which are
sent to the back-end.  Has slave classes for managing the various
queues which can build up.

=item L<Net::SSLeay::OO>

This module provides the interface to the OpenSSL library that this
stack uses, and in particular is used by SRS::EPP::Session to gather
information about the client certificate.

=item L<XML::Relax::Generate>

Relax NG to Moose class component.  The classes this module generates
are used as basis for below classes.

=item L<XML::Relax::Marshall>

XML to and from Moose data structure component.  This module can
create data structures which match the class structure made by
L<XML::Relax::Generate>

=item L<SRS::EPP::Message::*>

(based on) XML::Relax::Generate conversions of the various XML Schema
files in RFCs 3730 - 3733 (actually their later updates, RFC 4930 and
above) to Moose classes. These are marshalled to and from XML using
XML::Relax::Marshall, above.

=item L<SRS::Message::*>

These classes are similar conversions, but for the SRS protocol
messages.  These are based on a conversion of the Relax schema which
is used to generate the RFC (not yet assigned an IETF number).

=item L<Crypt::OpenPGP>

An oldie but a goodie, this module is a nice pure perl implementation
of PGP, which is used to sign requests and verify responses to and
from the SRS back-end system.

=back

=cut

