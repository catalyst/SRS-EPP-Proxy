

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

method to_srs() {
    my $epp = $self->message;

    my $payload = $epp->message->argument->payload;

    return XML::SRS::Handle::Query->new( handle_id_filter => $payload->ids );
}

has 'ids_to_check' =>
    is => 'rw',
    isa => 'ArrayRef[Str]',
    ;

has 'avail' =>
    is => "rw",
    isa => "HashRef[Str]",
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
    $self->avail({ map { $_->message->response->handle_id => 1 } grep { $_->message->response } @rs });

    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    my $ids = $payload->ids;
    my $avail = $self->avail();

    my @ids = map { XML::EPP::Contact::Check::ID->new(
                        name => $_,
                        available => ($avail->{$_} ? 0 : 1),
                        ) } @$ids;

    my $status = XML::EPP::Contact::Check::Status->new(
        id_status => \@ids,
    );

    my $r = XML::EPP::Contact::Check::Response->new(
        items => [ $status ],
    );

    # from SRS::EPP::Response::Check
    return $self->make_response(
        'Check',
        code => 1000,
        payload => $r,
        );
}

1;
