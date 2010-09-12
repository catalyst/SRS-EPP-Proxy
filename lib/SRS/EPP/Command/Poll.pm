
package SRS::EPP::Command::Poll;

use Moose;
extends 'SRS::EPP::Command';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;
use Digest::MD5 qw(md5_hex);
use SRS::EPP::Command::Info::Domain;

#use Module::Pluggable search_path => [__PACKAGE__];

with 'SRS::EPP::Command::PayloadClass';

# for plugin system to connect
sub xmlns {
	XML::EPP::Poll::Node::xmlns();
}

sub action {
	"poll";
}

sub clean_id_out {
	my $id = shift;
	our $min_token_type ||= Moose::Util::TypeConstraints::find_type_constraint(
		"XML::EPP::Common::minTokenType"
	);
	if ( $min_token_type->check($id) and $id !~ m{[%+]}) {
		return $id;
	}

	# not really urlencoding, but this is very minimal.
	$id =~ s{([%+\t\r\n\v])}{sprintf("%%%.2x",ord($1))}eg;
	$id =~ s{ }{+}g;
	$id;
}

sub clean_id_in {
	my $id = shift;
	if ($id =~ m{[+%]}) {
		$id =~ s{\+}{ }g;
		$id =~ s{%([0-9a-f]{2})}{chr(hex($1))}ieg;
	}
	$id;
}

method process( SRS::EPP::Session $session ) {
	$self->session($session);

	my $epp = $self->message;
	my $message = $epp->message;
	my $op = $message->argument->op;

	if ( $op eq "req" ) {
		return XML::SRS::GetMessages->new(
			queue => 1,
			max_results => 1,
			type_filter => [
				XML::SRS::GetMessages::TypeFilter->new(Type => "third-party"),
				XML::SRS::GetMessages::TypeFilter->new(
					Type => "server-generated-data"
				),
			],
		);
	}

	if ( $op eq "ack" ) {
		my $msgId = $message->argument->msgID;
		my ($registrar_id,$client_id) = $msgId =~ m/(....)(.*)/
			or return;
		return XML::SRS::AckMessage->new(
			transaction_id => clean_id_in($client_id),
			originating_registrar => $registrar_id+0,
			action_id => $self->client_id || $self->server_id,
		);
	}

	return $self->make_response(code => 2400);
}

sub extract_fact {
	my ($self,$action,$domain) = @_;

	if ( $action eq "DomainTransfer" ) {
		my $name = $domain->TransferredDomain();
		return "Domain Transfer",
			XML::EPP::Domain::Info::Response->new(
			name => $name,
			roid => substr(md5_hex($name), 0, 12) . '-DOM',
			transfer_date => $domain->timestamptz,
			status => [],
			);
	}

	if ( $action eq "DomainUpdate" ) {
		if ( $domain ) {
			if ( my $udai = $domain->UDAI() ) {
				return "New UDAI", XML::EPP::Domain::Info::Response->new(
					name => $domain->name,
					roid => substr(md5_hex($domain->name), 0, 12) . '-DOM',
					status => [
						SRS::EPP::Command::Info::Domain::getEppStatuses($domain)
					],
					auth_info => XML::EPP::Domain::AuthInfo->new(
						pw => XML::EPP::Common::Password->new(
							content => $udai,
						),
					),
				);
			}

			if ( $domain->audit()->comment() =~ m/RenewDomains/ ) {
				return "Domain Renewal", XML::EPP::Domain::Info::Response->new(
					name => $domain->name,
					roid => substr(md5_hex($domain->name), 0, 12) . '-DOM',
					status => [
						SRS::EPP::Command::Info::Domain::getEppStatuses($domain)
					],
					expiry_date => $domain->billed_until->timestamptz,
				);
			}

			# didn't notice anything specifically interesting, so we'll default to
			# returning a full info response...
			return (
				"Domain Update",
				SRS::EPP::Command::Info::Domain::buildInfoResponse($domain)
			);
		}
	}

	if ( $action eq "DomainCreate" ) {
		return (
			"Domain Create",
			SRS::EPP::Command::Info::Domain::buildInfoResponse($domain)
		);
	}

	return $action ? $action : "Unknown Message";
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $epp = $self->message;

	my $message = $rs[0]->message;
	my $responses = $message->responses;

	if ( !(scalar @$responses) ) {
		$self->log_info("$self: no responses - returning 1300");
		return $self->make_response(code => 1300);
	}

	if ( my $response = $responses->[0] ) {

		if ( $response->isa("XML::SRS::Message::Ack::Response") ) {
			$self->log_info("$self: ack response, ".$response->remaining." remaining");
			my $msgQ = XML::EPP::MsgQ->new(
				count => $response->remaining(),
				id => sprintf(
					"%04d%s",$response->registrar_id(),clean_id_out($response->tx_id()),
				),
			);
			return $self->make_response(code => 1000, msgQ => $msgQ);
		}

		if ( $response->isa("XML::SRS::Message") ) {
			my $record = $response->result();

			my $id = sprintf(
				"%04d%s", $record->by_id, clean_id_out($record->client_id),
			);

			for my $resp ( $record->response() ) {
				my $action = $record->action();
				$self->log_debug("$self: req processing a $action");
				my ($reason,$payload) = $self->extract_fact($action,$resp);
				my $mixed_msg = XML::EPP::MixedMsg->new(
					contents => [$reason],
					nodenames => [""],
				);
				my $msgQ = XML::EPP::MsgQ->new(
					count => $response->unacked(),
					id => $id,
					qDate => $record->server_time->timestamptz,
					msg => $mixed_msg,
				);
				return $self->make_response(
					code => 1301,
					payload => $payload, msgQ => $msgQ
				);
			}
		}
	}

	return $self->make_response(code => 2400);
}

1;
