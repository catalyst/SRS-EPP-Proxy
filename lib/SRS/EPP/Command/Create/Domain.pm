package SRS::EPP::Command::Create::Domain;

use Moose;
extends 'SRS::EPP::Command::Create';

with 'SRS::EPP::Common::Domain::NameServers';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;
use XML::SRS::Server::List;
use XML::SRS::Server;
use XML::SRS::Contact;
use XML::SRS::DS;
use XML::SRS::DS::List;

# for plugin system to connect
sub xmlns {
	return XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
	$self->session($session);

	my $epp = $self->message;
	my $message = $epp->message;
	my $payload = $message->argument->payload;

	$self->log_info("$self registering ".$payload->name);

	# find the admin contact
	my $contacts = $payload->contact;

	# create all the contacts (using their handles)
	my $contact_registrant = XML::SRS::Contact->new( handle_id => $payload->registrant() );
	$self->log_info("$self registrant = ".$payload->registrant);
	my ($contact_admin, $contact_technical);

	foreach my $contact (@$contacts) {
		if ( $contact->type eq 'admin' ) {
			if ($contact_admin) {
				$self->log_error("$self multiple admin contacts");
				return $self->make_error(
					code => 2306,
					message => 'Only one admin contact per domain supported',
				);
			}
			$contact_admin = XML::SRS::Contact->new( handle_id => $contact->value );
			$self->log_info("$self admin contact = ".$contact->value);
		}
		if ( $contact->type eq 'tech' ) {
			if ($contact_technical) {
				$self->log_error("$self multiple tech contacts");
				return $self->make_error(
					code => 2306,
					message => 'Only one tech contact per domain supported',
				);
			}
			$contact_technical = XML::SRS::Contact->new( handle_id => $contact->value );
			$self->log_info("$self tech contact = ".$contact->value);
		}
	}

	my $term = 1;
	my $default = " (default)";
	if ($payload->period) {
		$term = $payload->period->months;
		$default = "";
	}
	$self->log_info("$self registering for $term month(s)$default");

	my $request = XML::SRS::Domain::Create->new(
		domain_name => $payload->name(),
		term => $term,
		contact_registrant => $contact_registrant,
		$contact_admin ? (contact_admin => $contact_admin) : (),
		$contact_technical ? (contact_technical => $contact_technical) : (),
		action_id => $self->client_id || $self->server_id,
	);

	my $ns = $payload->ns ? $payload->ns->ns : undef;

	if ($ns) {
		my @ns_objs = eval { $self->translate_ns_epp_to_srs(@$ns); };
		my $error = $@;
		if ($error) {
			$self->log_error("$self error in nameservers; $error");
			return $error if $error->isa('SRS::EPP::Response::Error');
			die $error; # rethrow
		}
		$self->log_info("$self provided ".@ns_objs." nameserver(s)");

		my $list = XML::SRS::Server::List->new(
			nameservers => \@ns_objs,
		);

		$request->nameservers($list);
	}
	else {
		$self->log_info("$self: no nameservers provided");
	}
		
	my @ds;
	if ($message->extension) {
		foreach my $ext_obj (@{ $message->extension->ext_objs }) {
			if ($ext_obj->isa('XML::EPP::DNSSEC::Create')) {
				foreach my $epp_ds (@{$ext_obj->ds_data}) {
					push @ds, XML::SRS::DS->new(
						key_tag => $epp_ds->key_tag,
						algorithm => $epp_ds->alg,
						digest => $epp_ds->digest,
						digest_type => $epp_ds->digest_type,
					);
				};					
			}
		}
		
		$request->dns_sec(\@ds);
	}

	return $request;
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $epp = $self->message;
	my $eppMessage = $epp->message;
	my $eppPayload = $eppMessage->argument->payload;

	my $message = $rs[0]->message;
	my $response = $message->response;

	$self->log_info("$self: registered ".$response->name." OK");

	# let's create the returned create domain response
	my $r = XML::EPP::Domain::Create::Response->new(
		name => $response->name,
		created => $response->registered_date->timestamptz,
		expiry_date => $response->billed_until->timestamptz,
	);

	return $self->make_response(
		code => 1000,
		payload => $r,
	);
}

1;
