

package SRS::EPP::Command::Transfer::Domain;

use Moose;
extends 'SRS::EPP::Command::Transfer';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;

# for plugin system to connect
sub xmlns {
    XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
  $self->session($session);

  my $epp = $self->message;
  my $message = $epp->message;
  my $payload = $message->argument->payload;

  my $op = $message->argument->op;

  if ( $op eq "request" ) {
    # Get the auth info (could do some more validation here...)
    my $auth = $payload->auth_info();
    my $pass = $auth->pw();
    return (
      XML::SRS::Whois->new(
        domain => $payload->name,
        full => 0,
      ),
      XML::SRS::Domain::Update->new(
        filter => [$payload->name],
        action_id => $message->client_id || sprintf("auto.%x",time()),
        udai => $pass->content(),
      ),
    );
  }

  if ( $op eq "query" ) {
    return (
      XML::SRS::Whois->new(
        domain => $payload->name,
        full => 0,
      ),
      XML::SRS::Domain::Query->new(
        domain_name_filter => $payload->name,
      ),
    );
  }

  return $self->make_response(code => 2400);
}

method notify( SRS::EPP::SRSResponse @rs ) {
  my $epp = $self->message;

  for ( @rs ) {
    my $message = $_->message;
    my $response = $message->response;

    if ( $response ) {
      if ( $message->action() eq "Whois" ) {
        if ( $response->status eq "Available" ) {
          return $self->make_response(code => 2303);
        }
      }
      if ( $message->action() eq "DomainUpdate" ) {
        if ( $response->isa("XML::SRS::Domain") ) {
          return $self->make_response(code => 1000);
        }
      }
      if ( $message->action() eq "DomainDetailsQry" ) {
        if ( $response->status eq "Active" ) {
          # Then the transfer must have gone ok....
        }
      }
    }
  }

  return $self->make_response(code => 2400);
}


1;
