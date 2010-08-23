package SRS::EPP::Command::Update::Contact;

use Moose;

extends 'SRS::EPP::Command::Update';
with 'SRS::EPP::Common::Contact';

use feature 'switch';

use MooseX::Method::Signatures;

# for plugin system to connect
sub xmlns {
    return XML::EPP::Contact::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    $self->session($session);

    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # Reject add or remove elements, since those are just statuses which we don't support
    if ( $payload->add || $payload->remove) {
        return $self->make_response(code => 2307);
    }

    # Must supply a change element
    unless ( $payload->change ) {
        return $self->make_response(code => 2002);
    }

    my $contact = $payload->change;

    # Check they haven't given us some invalid fields
    if (my $resp = $self->validate_epp_contact($contact)) {
        return $resp;
    }

    my $address;
    my $name;
    if ($contact->postal_info) {
        $address = $self->translate_address($contact->postal_info->[0]->addr);

        # Blank out any optional fields they didn't provide in the address. Otherwise
        #  the original values will be left in by the SRS (EPP considers the
        #  address one unit to be replaced)
        for my $field (qw/address2 region postcode/) {
            $address->$field('') unless $address->$field;
        }
        
        $name = $contact->postal_info->[0]->name;
    }


    return (
        XML::SRS::Handle::Update->new(
            handle_id => $payload->id,
            action_id => $message->client_id || $self->server_id,
            ($name ? (name => $name) : ()),
            ($address ? (address => $address) : ()),
            ($contact->voice ? (phone => $contact->voice->content) : ()),
            ($contact->fax ? (fax => $contact->fax->content) : ()),
            ($contact->email ? (email => $contact->email) : ()),
        )
    );
}

method notify( SRS::EPP::SRSResponse @rs ) {
    return $self->make_response(code => 1000);
}



1;
