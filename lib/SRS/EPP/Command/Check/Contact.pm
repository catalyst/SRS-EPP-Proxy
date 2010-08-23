

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

method multiple_responses() { 1 }

method process( SRS::EPP::Session $session ) {
    $self->session($session);
    my $epp = $self->message;

    my $payload = $epp->message->argument->payload;

    return XML::SRS::Handle::Query->new( handle_id_filter => $payload->ids );
}

method notify( SRS::EPP::SRSResponse @rs ) {
    my $handles = $rs[0]->message->responses;

    my %used;
    %used = map { $_->handle_id => 1 } @$handles if $handles;

    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    my $ids = $payload->ids;

    my @ids = map { XML::EPP::Contact::Check::ID->new(
                        name => $_,
                        available => ($used{$_} ? 0 : 1),
                        ) } @$ids;

    my $status = XML::EPP::Contact::Check::Status->new(
        id_status => \@ids,
    );

    my $r = XML::EPP::Contact::Check::Response->new(
        items => [ $status ],
    );

    # from SRS::EPP::Response::Check
    return $self->make_response(
        code => 1000,
        payload => $r,
        );
}

1;
