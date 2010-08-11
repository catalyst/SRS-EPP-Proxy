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

  if (my $resp = $self->validate_epp_contact($payload)) {
    return $resp;   
  }
  
  my $epp_postal_info = $payload->postal_info();
  my $postalInfo = $epp_postal_info->[0];

  my $address = $self->translate_address($postalInfo->addr);

  if ( $address ) {
    my $txn = {
      handle_id => $payload->id(),
      name => $postalInfo->name(),
      phone => $payload->voice()->content(),
      address => $address,
      email => $payload->email(),
      action_id => $message->client_id || sprintf("auto.%x",time()),
    };
    if ( $payload->fax() && $payload->fax()->content() ) {
      $txn->{fax} = $payload->fax()->content();
    }
    if ( my $srsTxn =  XML::SRS::Handle::Create->new(%$txn) ) {
      return $srsTxn;
    }
  }

  # Catch all (possibly not necessary)
  return $self->make_response(code => 2400);
}


method notify( SRS::EPP::SRSResponse @rs ) {
  my $epp = $self->message;
  my $eppMessage = $epp->message;
  my $eppPayload = $eppMessage->argument->payload;

  my $message = $rs[0]->message;
  my $response = $message->response;

  if ( $response->isa("XML::SRS::Handle") ) {
    return $self->make_response(code => 1000);
  }

  return $self->make_response(code => 2400);
}

1;
