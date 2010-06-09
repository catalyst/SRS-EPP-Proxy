

package SRS::EPP::Command::Check::Contact;

use Moose;
extends 'SRS::EPP::Command::Check';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Contact;

# for plugin system to connect
sub xmlns {
    XML::EPP::Contact::Node::xmlns();
}

method to_srs( SRS::EPP::Session $session ) {
    $self->session($session);
    my $epp = $self->message;

    my $payload = $epp->message->argument->payload;

    return XML::SRS::Handle::Query->new( handle_id_filter => $payload->ids );
}

has 'avail' =>
    is => "rw",
    isa => "ArrayRef[Str]",
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
    $self->avail([ map { $_->message->ActionResponse->status } @rs ]);
};

method response() {
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    my @contacts = $payload->ids;

    $self->make_response(
        code => 1000,
        payload => XML::EPP::Contact::Check::Response->new(
            items => [
                map { XML::EPP::Contact::Check::Status->new(
                          name_status => XML::EPP::Contact::Check::Name->new(
                              name => $contacts[$_],
                              available => $self->avail->[$_],
                          ),
                          #reason =>
                          ) } 0..$#contacts
            ]
        ),
        );
}

1;
