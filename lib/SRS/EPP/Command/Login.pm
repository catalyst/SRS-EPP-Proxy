

package SRS::EPP::Command::Login;

use Moose;
extends 'SRS::EPP::Command';
use MooseX::Method::Signatures;
use Crypt::Password;
use Data::Dumper;

with 'MooseX::Log::Log4perl::Easy';

sub action {
	"login";
}

sub authenticated { 0 }

has "uid" =>
	is => "rw",
	isa => "XML::SRS::RegistrarId",
	;

has "server_id" =>
	is => "rw",
	isa => "Str",
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->session->new_server_id;
	},
	;

has "session" =>
	is => "rw",
	isa => "SRS::EPP::Session",
	weak_ref => 1,
	;

has "password" =>
	is => "rw",
	isa => "Str",
	;

has "login_ok" =>
	is => "rw",
	isa => "Bool",
	;

has "new_password" =>
	is => "rw",
	isa => "Str",
	;

has "password_changed" =>
	is => "rw",
	isa => "Bool",
	;

method to_srs( SRS::EPP::Session $session ) {
	$self->session($session);
	my $epp = $self->message;
	my $login = $epp->message->argument;
	my $uid = $login->client_id;
	$self->password($login->password);
	$self->new_password($login->new_password)
		if $login->new_password;
	$self->uid($uid);
	$self->session->want_user($uid);
	$session->stalled(1);

	return (XML::SRS::Registrar::Query->new(
		registrar_id => $uid,
	       ),
		XML::SRS::ACL::Query->new(
			Resource => "epp_connect",
			List => "allow",
			Type => "registrar_ip",
			filter_types => ["AddressFilter", "RegistrarIdFilter"],
			filter => [$session->peerhost, $uid],
		       ),
		($session->peer_cn ?
			 (
			XML::SRS::ACL::Query->new(
			Resource => "epp_client_certs",
			List => "allow",
			Type => "registrar_domain",
			filter_types => ["DomainNameFilter", "RegistrarIdFilter"],
			filter => [$session->peer_cn, $uid],
		       )) : () ),
	       );
}


method notify( SRS::EPP::SRSResponse @rs ) {
	if ( @rs > 1 ) {
		# response to login
		my $registrar = $rs[0];
		my $ip_ok_acl = $rs[1];
		my $cn_ok_acl = $rs[2];

		# fail by default
		$self->login_ok(0);

		# check the password
		my $password_ok;
		if ( my $auth = eval {
			$registrar->message->response->epp_auth
		} ) {
			$self->log_debug("checking provided password (".$self->password.") against ".Dumper($auth->crypted));
			$password_ok = $auth->check($self->password);
			$self->log_info("supplied password does not match")
				if !$password_ok;
		}
		else {
			$self->log_info("could not fetch password (denying login): $@");
		}

		# must be an entry on the allow list
		my $ip_ok;
		if ( my $entry = eval {
			$ip_ok_acl->message->response->entries->[0]
		       }) {
			$ip_ok = 1;
		}
		else {
			$self->log_info("no IP ACL found; denying login");
		}

		# the certificate must also have an entry
		my $cn_ok = 1;
		if ( my $entry = eval {
			scalar(@{ $cn_ok_acl->message->response->entries }) == 0
		}) {
			$cn_ok = 0;
			$self->log_info("no common name ACL found; denying login");
		}

		if ( $password_ok and $ip_ok and $cn_ok ) {
			$self->log_info("login as registrar ".$self->uid." successful");
			$self->login_ok(1);
			$self->session->user($self->uid);
		}
		else {
			$self->log_info("login as registrar ".$self->uid." unsuccessful");
		}
		$self->session->clear_want_user;
		$self->session->stalled(0);
	}
	else {
		# response to a password update
		my $registrar = $rs[0];
		if ( my $auth = eval {
			$registrar->message->response->epp_auth
		}) {
			my $ok = $auth->check($self->new_password);
			if ( $ok ) {
				$self->log_info("changed password successfully");
			}
			else {
				$self->log_error("failed to change password!");
			}
			$self->password_changed( $ok );
		}
	}
};

method done() {
	if ( defined $self->login_ok ) {
		# login result is back
		if ( $self->new_password ) {
			defined $self->password_changed;
		}
		else {
			1;
		}
	}
	else {
		0;
	}
}

method next_backend_message ( SRS::EPP::Session $session ) {
	die unless $self->new_password;
	XML::SRS::Registrar::Update->new(
		registrar_id => $self->uid,
		epp_auth => Crypt::Password::password( $self->new_password ),
		action_id => $self->server_id,
	       );
}

method response() {
	if ( $self->login_ok ) {
		if ( defined $self->new_password
			     and !$self->password_changed ) {
			$self->make_response(code => 2400);
		}
		else {
			$self->make_response(code => 1000);
		}
	}
	else {
		$self->make_response(code => 2200);
	}
}

1;
