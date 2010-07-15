package SRS::EPP::Command::Update::Domain;

use Moose;
extends 'SRS::EPP::Command::Update';
use MooseX::Method::Signatures;
use Crypt::Password;

my $allowed = {
    action => { add => 1, remove => 1 },
};

# for plugin system to connect
sub xmlns {
    return XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    $self->session($session);

    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # firstly check that we have at least one of add, rem and chg
    unless ( $payload->add or $payload->remove or $payload->change ) {
        return $self->make_response(code => 2002);
    }

    # create some vars we'll fill in shortly
    my ($registrant, $admin, $admin_old, $tech, $tech_old);

    # the first thing we're going to check for is a change to the registrant
    if ( $payload->change ) {
        if ( $payload->change->registrant ) {
            # changing the registrant, so let's remember that
            $registrant = $payload->change->registrant;
        }
    }

    # get the admin contacts (if there)
    $admin = extract_contact( $payload, 'add', 'admin' );
    $admin_old = extract_contact( $payload, 'remove', 'admin' );

    # get the tech contacts (if there)
    $tech = extract_contact( $payload, 'add', 'tech' );
    $tech_old = extract_contact( $payload, 'remove', 'tech' );

    # make sure that we have neither or both admin contacts
    if ( $admin xor $admin_old ) {
        # something is wrong since only one is defined and the other isn't
        return $self->make_response(code => 2002);
    }

    # make sure that we have neither or both tech contacts
    if ( $tech xor $tech_old ) {
        # something is wrong since only one is defined and the other isn't
        return $self->make_response(code => 2002);
    }

    return XML::SRS::Domain::Update->new(
        filter => [ $payload->name() ],
        ( $registrant ? ( registrant_id => $registrant ) : () ),
        ( $admin ? (contact_admin => XML::SRS::Contact->new( handle_id => $admin )) : () ),
        ( $tech ? (contact_technical => XML::SRS::Contact->new( handle_id => $tech )) : () ),
        action_id => $message->client_id || sprintf('auto.%x', time()),
    );
}

sub extract_contact {
    my ($payload, $action, $type ) = @_;

    # check the input
    die q{Program error: '$action' should be 'add' or 'remove'}
        unless $allowed->{action}{$action};

    # check that action is there
    return unless $payload->$action;

    my $contacts = $payload->$action->contact;
    foreach my $c ( @$contacts ) {
        return $c->value if $c->type eq $type;
    }
    return;
}

method notify( SRS::EPP::SRSResponse @rs ) {
    my $epp = $self->message;
    my $eppMessage = $epp->message;
    my $eppPayload = $eppMessage->argument->payload;

    my $message = $rs[0]->message;
    my $responses = $message->responses;

    # if we get no response, then it's likely the domain name doesn't exist
    # ie. the DomainNameFilter didn't match anything
    unless ( @$responses ) {
        # Object does not exist
        return $self->make_response(code => 2303);
    }

    # check the response wasn't an error
    if ( $responses->[0]->isa('XML::SRS::Error') ) {
        return $self->make_response(code => 2400);
    }

    # everything looks ok, so let's return a successful message
    return $self->make_response(code => 1000);
}

1;
