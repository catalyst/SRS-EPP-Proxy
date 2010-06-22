

package SRS::EPP::Command::Check::Domain;

use Moose;
extends 'SRS::EPP::Command::Check';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;

# for plugin system to connect
sub xmlns {
    XML::EPP::Domain::Node::xmlns();
}

method to_srs() {
	my $epp = $self->message;

    my $payload = $epp->message->argument->payload;

    my @domains = $payload->names;

	return map {
        XML::SRS::Whois->new(
            domain => $_,
            full => 0,
            );
    } @domains;
}

has 'avail' =>
    is => "rw",
    isa => "ArrayRef[Str]",
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
    $self->avail([ map { $_->message->response->status } @rs ]);
	my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    my @domains = $payload->names;

    my $r = XML::EPP::Domain::Check::Response->new(
        items => [
            map { XML::EPP::Domain::Check::Status->new(
                      name_status => XML::EPP::Domain::Check::Name->new(
                          name => $domains[$_],
                          available => ($self->avail->[$_] eq 'Available' ? 1 : 0),
                      ),
                      #reason =>
                      ) } 0..$#domains
        ]
    );

    # from SRS::EPP::Response::Check
    return $self->make_response(
        'Check',
        code => 1000,
        payload => $r,
        );
};

1;
