package SRS::EPP::Command::Create::Domain;

use Moose;
extends 'SRS::EPP::Command::Create';

with 'SRS::EPP::Common::Domain::NameServers';

use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;
use XML::SRS::Server::List;
use XML::SRS::Server;
use XML::SRS::Contact;

# for plugin system to connect
sub xmlns {
    return XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    $self->session($session);

    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # find the admin contact
    my $contacts = $payload->contact;

    # create all the contacts (using their handles)
    my $contact_registrant = XML::SRS::Contact->new( handle_id => $payload->registrant() );
    my ($contact_admin, $contact_technical);

    foreach my $contact ( @$contacts ) {
        if ( $contact->type eq 'admin' ) {
            if ($contact_admin) {
                return $self->make_response(
                    Error => (
                        code      => 2306,
                        exception => XML::EPP::Error->new(
                            value  => '',
                            reason => 'Only one admin contact per domain supported',
                        ),
                    )
                );
            }
            $contact_admin = XML::SRS::Contact->new( handle_id => $contact->value );
        }
        if ( $contact->type eq 'tech' ) {
            if ($contact_technical) {
                return $self->make_response(
                    Error => (
                        code      => 2306,
                        exception => XML::EPP::Error->new(
                            value  => '',
                            reason => 'Only one tech contact per domain supported',
                        ),
                    )
                );
            }
            $contact_technical = XML::SRS::Contact->new( handle_id => $contact->value );
        }
    }

    my $term = 1;
    if ($payload->period) {
        $term = $payload->period->months;
    }

    my $request = XML::SRS::Domain::Create->new(
        domain_name => $payload->name(),
        term => $term,
        contact_registrant => $contact_registrant,
        $contact_admin ? (contact_admin => $contact_admin) : (),
        $contact_technical ? (contact_technical => $contact_technical) : (),
	action_id => $self->client_id || $self->server_id,
    );

    my $ns = $payload->ns ? $payload->ns->ns : undef;

    if ($ns) {
        my @ns_objs = eval { $self->translate_ns_epp_to_srs(@$ns); };
        my $error = $@;
        if ($error) {
            return $error if $error->isa('SRS::EPP::Response::Error');
            die $error; # rethrow
        }

        my $list = XML::SRS::Server::List->new(
            nameservers => \@ns_objs,
        );

        $request->nameservers($list);
    }

    return $request;
}

method notify( SRS::EPP::SRSResponse @rs ) {
    my $epp = $self->message;
    my $eppMessage = $epp->message;
    my $eppPayload = $eppMessage->argument->payload;

    my $message = $rs[0]->message;
    my $response = $message->response;

    # let's create the returned create domain response
    my $r = XML::EPP::Domain::Create::Response->new(
        name => $response->name,
        created => $response->registered_date->timestamptz,
        expiry_date => $response->billed_until->timestamptz,
    );

    return $self->make_response(
        code => 1000,
        payload => $r,
    );
}

1;
