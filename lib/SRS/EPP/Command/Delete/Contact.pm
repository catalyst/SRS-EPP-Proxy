

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

method notify( SRS::EPP::SRSResponse @rs ) {
  my $message = $rs[0]->message;
  my $response = $message->response;

  if ( ! $response ) {
    # That means everything worked
    return $self->make_response(code => 1000);
  }

  if ( $response->isa("XML::SRS::Error") ) {
    if ( $response->ErrorId() eq "HANDLE_DOES_NOT_EXIST" ) {
      return $self->make_response(code => 2303);
    }
  }
  return $self->make_response(code => 2400);
}

1;
