
package SRS::EPP::Command::Delete::Domain;

use Moose;
extends 'SRS::EPP::Command::Delete';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;

# for plugin system to connect
sub xmlns {
	XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
	$self->session($session);
	my $epp = $self->message;
	my $message = $epp->message;

	my $payload = $message->argument->payload;
	my $action_id = $self->client_id || $self->server_id;

	return XML::SRS::Domain::Update->new(
		filter => [$payload->name],
		action_id => $action_id,
		cancel => 1,
		full_result => 0,
	);
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $message = $rs[0]->message;
	my $response = $message->response;

	if ( !$response ) {

		# Lets just assume the domain doesn't exist
		return $self->make_response(code => 2303);
	}
	if ( $response->can("status") ) {
		if ( $response->status eq "Available" || $response->status eq 'PendingRelease' ) {
			return $self->make_response(code => 1000);
		}
	}
	return $self->make_response(code => 2400);
}

method make_error_response( ArrayRef[XML::SRS::Error] $srs_errors ) {

	# If we get an error about a missing UDAI, then this must be a
	#   domain the registrar doesn't own. Return an appropriate
	#   epp error
	foreach my $srs_error (@$srs_errors) {
		if ($srs_error->error_id eq 'MISSING_MANDATORY_FIELD') {
			if ($srs_error->details && $srs_error->details->[0] eq 'UDAI') {
				return $self->make_error(
					code    => 2201,
					message => 'Authorization Error',
				);
			}
		}
	}

	return $self->SUPER::make_error_response($srs_errors);
}

1;
