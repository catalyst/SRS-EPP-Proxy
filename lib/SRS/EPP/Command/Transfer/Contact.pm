package SRS::EPP::Command::Transfer::Contact;

use Moose;
extends 'SRS::EPP::Command::Transfer';
use MooseX::Method::Signatures;
use SRS::EPP::Session;

# for plugin system to connect
sub xmlns {
    XML::EPP::Contact::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    return $self->make_response(code => 2101);
}

1;
