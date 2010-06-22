

package SRS::EPP::Command::Delete::Contact;

use Moose;
extends 'SRS::EPP::Command::Delete';
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
    my $message = $epp->message;

    my $payload = $message->argument->payload;
    my $action_id = $message->client_id || sprintf("auto.%x",time());

    return XML::SRS::Handle::Update->new(
            handle_id => $payload->id,
            action_id => $action_id,
            delete => 1,
            );
}

has 'code' => (
    is => "rw",
    isa => "Int",
    lazy => 1,
    default => 2400,   # Command failed
);

method notify( SRS::EPP::SRSResponse @rs ) {
  my $message = $rs[0]->message;
  my $response = $message->response;

  if ( ! $response ) {
    # That means everything worked
    return $self->code(1000);
  }

  if ( $response->isa("XML::SRS::Error") ) {
    if ( $response->ErrorId() eq "HANDLE_DOES_NOT_EXIST" ) {
      return $self->code(2303);
    }
  }
};

method response() {
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    $self->make_response(code => $self->code());
}

1;