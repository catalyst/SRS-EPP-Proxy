package SRS::EPP::Command::Info::Domain;

use Moose;
extends 'SRS::EPP::Command::Info';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use Data::Dumper;

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

    #print 'whois=' . $whois->to_xml() if $whois;
    #print 'domain=' . $domain->to_xml() if $domain;

    # here we have a few choices:
    # - if Whois Status="Available", then we don't have a domain to report on
    # - if Whois Status="Active", then we _may_ have a domain to report on
    # - - if DomainDetails suceeded, we report the details
    # - - if DomainDetails failed, the user isn't allowed to see it

    if ( $whois->status eq 'Available' ) {
        # since this is available, we already know the result
        return $self->make_response(code => 2303);
    }

    # make the Info::Response object
    my $r = XML::EPP::Domain::Info::Response->new();

    return $self->make_response(
        'Info',
        code => 1000,
        payload => $r,
    );

    return;
}

1;
