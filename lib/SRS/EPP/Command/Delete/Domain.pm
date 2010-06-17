

package SRS::EPP::Command::Delete::Domain;

use Moose;
extends 'SRS::EPP::Command::Delete';
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
    my $message = $epp->message;

    my $payload = $message->argument->payload;
    my $action_id = $message->client_id || sprintf("auto.%x",time());

    return XML::SRS::Domain::Update->new(
            filter => [$payload->name],
            action_id => $action_id,
            cancel => 1,
            full_result => 0,
            );
}

has 'code' => (
    is => "rw",
    isa => "Int",
    default => 2400,   # Command failed
);

method notify( SRS::EPP::SRSResponse @rs ) {
  my $message = $rs[0]->message;
  my $response = $message->response;

  if ( ! $response ) {
    # Lets just assume the domain doesn't exist
    return $self->code(2303);
  }

  if ( $response->status eq "Available" ) {
    return $self->code(1000);
  }
};

method response() {
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    $self->make_response(code => $self->code());
}

1;
