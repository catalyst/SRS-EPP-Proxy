#
# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

package SRS::EPP::Proxy;

use MooseX::Singleton;
use MooseX::Method::Signatures;

use SRS::EPP::Session;

our $VERSION = "0.00_01";

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

has 'child_pids' =>
	is => "ro",
	isa => "ArrayRef[Int]",
	default => sub { [] },
	;

method accept_loop() {
	while ( my $socket = $self->listener->accept ) {
		if ( my $pid = fork ) {
			push @{ $self->child_pids }, $pid;
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

