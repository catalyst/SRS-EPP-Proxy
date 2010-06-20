package SRS::EPP::Command::Info::Contact;

use Moose;
extends 'SRS::EPP::Command::Info';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Contact;
use Data::Dumper;

use XML::EPP::Contact::Info::Response;
use XML::EPP::Contact::PostalInfo;
use XML::EPP::Contact::Addr;

# for plugin system to connect
sub xmlns {
    XML::EPP::Contact::Node::xmlns();
}

method to_srs() {
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    # ToDo: check to see if the AuthInfo has been passed in and figure out what
    # to do with it here

    return XML::SRS::Handle::Query->new( handle_id_filter => $payload->id );
}

has 'saved_response' =>
    is => 'rw',
    isa => 'XML::EPP::Contact::Info::Response',
    ;

method notify( SRS::EPP::SRSResponse @rs ) {
    my $message = $rs[0]->message;
    my $response = $message->response;

    unless ( $response ) {
        # assume the contact doesn't exist
        return $self->code(2303);
    }

    # make the Info::Response object
    my $r = XML::EPP::Contact::Info::Response->new(
        id => $response->handle_id,
        # roid => ?,
        # status => [ $self->message->status ],
        postal_info => [ XML::EPP::Contact::PostalInfo->new(
            name => $response->name,
            # org => ,
            addr => XML::EPP::Contact::Addr->new(
                street => [ $response->address->address1, $response->address->address2],
                city   => $response->address->city,
                sp     => $response->address->region, # state or province
                pc     => $response->address->postcode,
                cc     => $response->address->cc,
            ),
        ) ],
        voice => XML::EPP::Contact::E164->new(
            content => $response->phone->cc . $response->phone->ndc . $response->phone->subscriber,
        ),
        #fax => XML::EPP::Contact::E164->new(
        #    content => $response->phone->cc . $response->phone->ndc . $response->phone->subscriber,
        #),
        # fax => ,
        email => $response->email,
    );

    $self->saved_response($r);
};

method response() {
    print Dumper( $self->saved_response );

    return $self->make_response(
        'Info',
        code => 1000,
        payload => $self->saved_response,
    );
}

1;
