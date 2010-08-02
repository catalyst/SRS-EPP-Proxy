package SRS::EPP::Command::Create::Domain;

use Moose;
extends 'SRS::EPP::Command::Create';
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

    # ToDo: should we check here that there are two registrants and that they
    # are type="admin" and type="tech"

    # find the admin contact
    my $contacts = $payload->contact;

    # create all the contacts (using their handles)
    my $contact_registrant = XML::SRS::Contact->new( handle_id => $payload->registrant() );
    my ($contact_admin, $contact_technical);
    foreach my $contact ( @$contacts ) {
        if ( $contact->type eq 'admin' ) {
            $contact_admin = XML::SRS::Contact->new( handle_id => $contact->value );
        }
        if ( $contact->type eq 'tech' ) {
            $contact_technical = XML::SRS::Contact->new( handle_id => $contact->value );
        }
    }

    my $ns = $payload->ns->ns;
    my $list = XML::SRS::Server::List->new(
        nameservers => [ map { XML::SRS::Server->new( fqdn => $_ ) } @$ns ],
        );

    return XML::SRS::Domain::Create->new(
        domain_name => $payload->name(),
        term => 1, # ToDo: check this
        contact_registrant => $contact_registrant,
        contact_admin => $contact_admin,
        contact_technical => $contact_technical,
        nameservers => $list,
        action_id => $message->client_id || sprintf('auto.%x',time()),
    );
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
