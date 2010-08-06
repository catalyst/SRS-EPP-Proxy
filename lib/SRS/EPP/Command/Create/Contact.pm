

package SRS::EPP::Command::Create::Contact;

use Moose;
extends 'SRS::EPP::Command::Create';
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


  my $epp_postal_info = $payload->postal_info();
  if ( (scalar @$epp_postal_info) != 1 ) {
    # The SRS doesn't support the US's idea of i18n.  That is
    # that ASCII=international, anything else=local.
    # Instead, well accept either form of postalinfo, but throw an 
    # error if they try to provide both types (because the SRS can't
    # have two translations for one address)
    return $self->make_response(code => 2400);
  }
  my $postalInfo = $epp_postal_info->[0];

  # The SRS doesn't have a 'org' field, we don't want to lose info, so
  if ( $postalInfo->org ) {
    return $self->make_response(
        Error => (
            code => 2306,
            exception => XML::EPP::Error->new(
                value => $postalInfo->org,            
                reason => 'org field not supported',
            ),
        )
    );
  }

  # Try to make an SRS address object...
  my $postalInfoAddr = $postalInfo->addr();
  my $street = $postalInfoAddr->street();
  my $address = XML::SRS::Contact::Address->new(
    address1 => $street->[0],
    city => $postalInfoAddr->city,
    ($postalInfoAddr->sp ? (region => $postalInfoAddr->sp) : ()),
    cc => $postalInfoAddr->cc,
    ($postalInfoAddr->pc ? (postcode => $postalInfoAddr->pc) : ()),
  );
  if ( $address ) {
    if ( $street->[1] ) {
      $address->address2($street->[1]);
    }

    # and finally, an SRS update is (hopefully) produced..
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
