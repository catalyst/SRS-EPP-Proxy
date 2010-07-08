

package SRS::EPP::Command::Renew::Domain;

use Moose;
extends 'SRS::EPP::Command::Renew';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;

# for plugin system to connect
sub xmlns {
    XML::EPP::Domain::Node::xmlns();
}

method duplicateRenew ( XML::SRS::TimeStamp $domainDate, Str $txnDate ) {
  # This is a bit mad!
  # The idea is that we just want to ensure that the same transaction doesn't
  # get repeated, and renew a domain twice.
  # 
  # We are going to be very forgiving here - if the
  # String provied as part of the EPP transaction is within a few days of the
  # billed_until date on the domain - we'll allow the renew to happen

  my $domEpoch = $domainDate->epoch();
  my $txnEpoch = XML::SRS::TimeStamp->new(timestamp => "$txnDate 00:00:00")->epoch();

  my $diff = $domEpoch - $txnEpoch;
  return abs($diff) > (86400*2);
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

  if ( ! $self->billed_until() ) {
    # This must be a response to our query TXN

    if ( $response ) {
      if ( $response->status eq "Available" ) {
        return $self->make_response(code => 2303);
      }
      if ( my $billDate = $response->billed_until() ) {
          if ( ! $self->duplicateRenew($billDate,$eppPayload->expiry_date) ) {
            $self->billed_until($response->billed_until());
            return XML::SRS::Domain::Update->new(
              filter => [$response->name],
              action_id => $eppMessage->client_id || sprintf("auto.%x",time()),
              renew => 1,
              term => $eppPayload->period->value,
              );
          }
      }
    }
    return $self->make_response(code => 2400);
  }

  # By now, we must be dealing with the response to our update TXN
  if ( ! $response ) {
    # We found the bill_date of the domain, but didn't update it
    # - Assume the domain isn't managed by this registrar
    return $self->make_response(code => 2201);
  }

  if ( $response->can("billed_until") ) {
    # TODO, actual check for success?
    return $self->make_response(code => 1000);
  }

  return $self->make_response(code => 2400);
}

1;
