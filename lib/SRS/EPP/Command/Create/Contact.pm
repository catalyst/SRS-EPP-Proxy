package SRS::EPP::Command::Create::Contact;

use Moose;

extends 'SRS::EPP::Command::Create';
with 'SRS::EPP::Common::Contact';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Contact;
use XML::SRS::TimeStamp;

# for plugin system to connect
sub xmlns {
	return XML::EPP::Contact::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
	$self->session($session);

	my $epp = $self->message;
	my $message = $epp->message;
	my $payload = $message->argument->payload;
	my $error;

	my $epp_postal_info = $payload->postal_info()
		or return $self->make_error(
		code => 2306,
		message => "Postal information must be provided",
		);

	if ($error = $self->validate_contact_postal($epp_postal_info)) {
		return $error;
	}

	my $postal_info = $epp_postal_info->[0];

	my $address = $self->translate_address($postal_info->addr)
		or goto error_out;

	my $voice = $payload->voice
		or return $self->make_error(
		code => 2306,
		message => "Voice phone number must be provided",
		);

	if ($error = $self->validate_contact_voice($voice)) {
		return $error;
	}

	my $txn = {
		handle_id => $payload->id(),
		name => $postal_info->name(),
		phone => $payload->voice()->content(),
		address => $address,
		email => $payload->email(),
		action_id => $self->client_id || $self->server_id,
	};

	if ( $payload->fax() && $payload->fax()->content() ) {
		$txn->{fax} = $payload->fax()->content();
	}

	my $srsTxn = XML::SRS::Handle::Create->new(%$txn)
		or goto error_out;

	$self->log_info( "$self: prepared HandleCreate, ActionId = " .$txn->{action_id} );

	return $srsTxn;

error_out:

	# Catch all (possibly not necessary)
	return $self->make_response(code => 2400);
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $message = $rs[0]->message;
	my $response = $message->response;

	$self->log_info(
		"$self: Handle ".$response->handle_id
			." created OK"
	);

	my $r = XML::EPP::Contact::Create::Response->new(
		id => $response->handle_id,
		created => $message->server_time->timestamptz,
	);

	return $self->make_response(
		code => 1000,
		payload => $r,
	);
}

1;
