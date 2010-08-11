package SRS::EPP::Command::Info::Domain;

use Moose;

extends 'SRS::EPP::Command::Info';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

use XML::EPP::Common;
use XML::EPP::Domain::NS;
use XML::EPP::Domain::HostAttr;
use XML::SRS::FieldList;

# for plugin system to connect
sub xmlns {
    XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    $self->session($session);
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    # we're not supporting authInfo, so get out of here with an EPP response
    if ( $payload->has_auth_info ) {
        return $self->make_response(code => 2307);
    }

    my %ddq_fields = (
        delegate           => 1,
        registered_date    => 1,
        registrar_id       => 1,
        billed_until       => 1,
        audit_text         => 1,
        effective_from     => 1,
        registrant_contact => 1,
        admin_contact      => 1,
        technical_contact  => 1,   
    );
    
    # We only want to return name servers if the 'hosts' attribute is 'all' or 'del'
    $ddq_fields{name_servers} = 1 if $payload->name->hosts eq 'all' || $payload->name->hosts eq 'del'; 

	return (
        XML::SRS::Whois->new(
            domain => $payload->name->value,
            full => 0,
        ),
        XML::SRS::Domain::Query->new(
            domain_name_filter => $payload->name->value,
            field_list => XML::SRS::FieldList->new(
                %ddq_fields,
            ),
        )
    );
}

method notify( SRS::EPP::SRSResponse @rs ) {
    # check there are two responses
    my $whois = $rs[0]->message->response;
    my $domain = $rs[1]->message->response;
    
    # if status is available, then the object doesn't exist
    if ( $whois->status eq 'Available' ) {
        # since this is available, we already know the result is 'Object does not exist'
        return $self->make_response(code => 2303);
    }

    # if there was no domain, this registrar doesn't have access to it
    unless ( $domain ) {
        return $self->make_response(code => 2201);
    }

    # we have a domain, therefore we have a full response :)
    # let's do this one bit at a time
    my $payload = $self->message->message->argument->payload;

    return $self->make_response(
        code => 1000,
        payload => buildInfoResponse($domain),
    );
}

sub buildInfoResponse {
  my ($domain) = @_;

  # get some things out to make it easier on the eye below
  my $nsList;
  if ( $domain->nameservers ) {
      my @nameservers = map { XML::EPP::Domain::HostAttr->new(name => $_->fqdn) } 
        @{$domain->nameservers->nameservers};
      $nsList = XML::EPP::Domain::NS->new( ns => [ @nameservers ] );
  }
  
  my %contacts;
  for my $type (qw(registrant admin technical)) {
      my $method = 'contact_'.$type;
      my $contact = $domain->$method;

      next unless $contact && $contact->handle_id;
      
      if ($contact) {
        if ($type eq 'registrant') {
            $contacts{$type} = $contact->handle_id;
        }
        else {
            my $epp_type = $type eq 'technical' ? 'tech' : $type;
            push @{$contacts{contact}}, XML::EPP::Domain::Contact->new(
                value => $contact->handle_id,
                type => $epp_type,
            );
        }
      }
  }

  return XML::EPP::Domain::Info::Response->new(
      name => $domain->name,
      roid => substr(md5_hex($domain->name), 0, 12) . '-DOM',
      status => [ getEppStatuses($domain) ],
      %contacts,
      ($nsList ? (ns => $nsList) : ()),
      client_id => sprintf("%03d",$domain->registrar_id()), # clID
      created => ($domain->registered_date())->timestamptz, # crDate
      expiry_date => ($domain->billed_until())->timestamptz, # exDate
      updated => ($domain->audit->when->begin())->timestamptz, # upDate
  );
}

sub getEppStatuses {
  my ($domain) = @_;

  my @status;
  if ( $domain->delegate() == 0 ) {
      push @status, 'inactive';
  }
  elsif ( $domain->status eq 'PendingRelease' ) {
      push @status, 'pendingDelete';
  }
  elsif ( defined $domain->locked_date() ) {
      push @status, qw( serverDeleteProhibited serverHold serverRenewProhibited serverTransferProhibited serverUpdateProhibited );
  }
  else {
      push @status, 'ok';
  }

  return map { XML::EPP::Domain::Status->new( status => $_ ) } @status
}

1;
