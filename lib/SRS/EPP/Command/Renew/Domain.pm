

package SRS::EPP::Command::Renew::Domain;

use Moose;
extends 'SRS::EPP::Command::Renew';
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

  return XML::SRS::Whois->new(
    domain => $payload->name(),
    );
}

has 'billed_until' =>
    is => "rw",
    isa => "XML::SRS::TimeStamp",
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
  my $epp = $self->message;
  my $eppMessage = $epp->message;
  my $eppPayload = $eppMessage->argument->payload;

  my $message = $rs[0]->message;
  my $response = $message->response;

  if ( $self->billed_until() ) {
    # This must be a response to our update TXN
    if ( ! $response ) {
      # We found the bill_date of the domain, but didn't update it
      # - Assume the domain isn't managed by this registrar
      return $self->make_response(code => 2201);
    }

    if ( $response->can("billed_until") ) {
      my $newBillDate = $response->billed_until();
      # TODO, actual check for success?
      return $self->make_response(code => 1000);
    }

    return $self->make_response(code => 2400);
  } else {
    # This must be a response to our query TXN

    if ( $response ) {
      if ( $response->can("billed_until") ) {
        $self->billed_until($response->billed_until());
        return XML::SRS::Domain::Update->new(
            filter => [$response->name],
            action_id => $eppMessage->client_id || sprintf("auto.%x",time()),
            renew => 1,
            term => $eppPayload->period->value,
            );
      }
      if ( $response->can("status") ) {
        if ( $response->status eq "Available" ) {
          return $self->make_response(code => 2303);
        }
      }
    }
    return $self->make_response(code => 2400);
  }
}

1;
