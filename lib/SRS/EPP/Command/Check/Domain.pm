

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

method to_srs( SRS::EPP::Session $session ) {
	$self->session($session);
	my $epp = $self->message;

    # print "epp=$epp\n";
    my $payload = $epp->message->argument->payload;
    # print "payload=$payload\n";

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
    $self->avail([ map { $_->message->ActionResponse->status } @rs ]);
};

method response() {
	my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    my @domains = $payload->names;

    $self->make_response(
        code => 1000,
        payload => XML::EPP::Domain::Check::Response->new(
            items => [
                map { XML::EPP::Domain::Check::Status->new(
                          name_status => XML::EPP::Domain::Check::Name->new(
                              name => $domains[$_],
                              available => $self->avail->[$_],
                          ),
                          #reason => 
                          ) } 0..$#domains
            ]
        ),
        );
}

1;
