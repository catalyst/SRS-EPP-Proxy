

package SRS::EPP::Command::Transfer::Domain;

use Moose;
extends 'SRS::EPP::Command::Transfer';

use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints();
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;
use XML::SRS::Types;

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
    my $udaiType = Moose::Util::TypeConstraints::find_type_constraint("XML::SRS::UDAI");
    if ( ! $udaiType->check($pass->content()) ) {
      return $self->make_response(code => 2202);
    }

    return (
      XML::SRS::Whois->new(
        domain => $payload->name,
        full => 0,
      ),
      XML::SRS::Domain::Update->new(
        filter => [$payload->name],
        action_id => $message->client_id || sprintf("auto.%x",time()),
        udai => $pass->content(),
        convert_contacts_to_handles => 1,
      ),
    );
  }

  if ( $op eq "query" ) {
    my $msg = "This server does support pending transfers";
    return $self->make_response(code => 2102, extra => $msg);
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
          my $epp_resp = XML::EPP::Domain::Transfer::Response->new(
            name => $response->name,
            trStatus => 'serverApproved',
            requester => $response->registrar_id,
            requested => $response->audit->when->begin->timestamptz,
            action_id =>  $response->registrar_id,
            action_date => $response->audit->when->begin->timestamptz,
          );            
            
          return $self->make_response(
            code => 1000,
            payload => $epp_resp,            
          );
        }
      }
    }
  }

  return $self->make_response(code => 2400);
}

method make_error_response( ArrayRef[XML::SRS::Error] $srs_errors ) {
    # If we get the below error, it's because we've tried to transfer a domain
    #  the registrar already owns. We don't want to return this to the client.
    foreach my $srs_error (@$srs_errors) {
        if ($srs_error->error_id eq 'CONVERT_TO_HANDLES_ONLY_FOR_TRANSFER') {
            
            my $epp = $self->message;
            my $message = $epp->message;
            my $payload = $message->argument->payload;
            
            return $self->make_response(
                Error => (
                    code      => 2002,
                    exception => XML::EPP::Error->new(
                        value  => $payload->name,
                        reason => 'Cannot transfer a domain you already own',
                    ),
                )
            );        
        }
    }
        
    return $self->SUPER::make_error_response($srs_errors);
}

1;
