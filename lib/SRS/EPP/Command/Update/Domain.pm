package SRS::EPP::Command::Update::Domain;

use Moose;
extends 'SRS::EPP::Command::Update';
use MooseX::Method::Signatures;
use Crypt::Password;

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

    my $registrant;

    # the first thing we're going to check for is a change to the registrant
    if ( $payload->change ) {
        if ( $payload->change->registrant ) {
            use Data::Dumper;
            print Dumper($payload->change);
            # changing the registrant, so let's remember that
            $registrant = $payload->change->registrant;
        }
    }

    return XML::SRS::Domain::Update->new(
        filter => [ $payload->name() ],
        ( $registrant ? ( registrant_id => $registrant ) : () ),
        action_id => $message->client_id || sprintf('auto.%x', time()),
    );
}

method notify( SRS::EPP::SRSResponse @rs ) {
    my $epp = $self->message;
    my $eppMessage = $epp->message;
    my $eppPayload = $eppMessage->argument->payload;

    my $message = $rs[0]->message;
    my $responses = $message->responses;

    # print Dumper($message);

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

    # we have a response, so let's check it looks ok
    die 'Not yet implemented';

    return $self->make_response(code => 1000);
}

1;
