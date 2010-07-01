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
use XML::EPP::Domain::NS::List;


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

	return (
        XML::SRS::Whois->new(
            domain => $payload->name->value,
            full => 0,
        ),
        XML::SRS::Domain::Query->new(
            domain_name_filter => $payload->name->value
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
    # print Dumper($domain);

    # get some things out to make it easier on the eye below
    my @nameservers = map { $_->fqdn } @{$domain->nameservers->nameservers};

    my $r = XML::EPP::Domain::Info::Response->new(
        name => $payload->name->value,
        roid => substr(md5_hex($payload->name->value), 0, 12) . '-DOM',
        # status => \@status,
        status => [ getEppStatuses($domain) ],
        # registrant # skipping, since contacts can't be seen from EPP
        # contact    # skipping, since contacts can't be seen from EPP
        ns => XML::EPP::Domain::NS::List->new( ns => [ @nameservers ] ),
        # host # not doing this
        client_id => $domain->registrar_id(), # clID
        # crID => '',
        created => srs_date_to_epp_date($domain->registered_date()), # crDate
        expiry_date => srs_date_to_epp_date($domain->billed_until()), # exDate
        # upID
        updated => srs_date_to_epp_date($domain->audit->when->begin()), # upDate
        # trDate
        # authInfo
    );

    return $self->make_response(
        'Info',
        code => 1000,
        payload => $r,
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

sub srs_date_to_epp_date {
    my ($srs) = @_;

    return
        $srs->year
        . '-'
        . $srs->month
        . '-'
        . $srs->day
        . 'T'
        . $srs->hour
        . ':'
        . $srs->minute
        . ':'
        . $srs->second
        . $srs->tz_offset
    ;
}

1;
