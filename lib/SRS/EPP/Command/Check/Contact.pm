

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

has 'avail' =>
    is => "rw",
    isa => "ArrayRef[Str]",
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
    $self->avail([ map { $_->message->ActionResponse->status } @rs ]);
};

1;
