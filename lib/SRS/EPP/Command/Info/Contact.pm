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

method process( SRS::EPP::Session $session ) {
    $self->session($session);
    my $epp = $self->message;
    my $payload = $epp->message->argument->payload;

    # we're not supporting authInfo, so get out of here with an EPP response
    if ( $payload->has_auth_info ) {
        return $self->make_response(code => 2307);
    }

    return XML::SRS::Handle::Query->new( handle_id_filter => $payload->id );
}

has 'code' => (
    is => "rw",
    isa => "Int",
);

method notify( SRS::EPP::SRSResponse @rs ) {
    my $message = $rs[0]->message;
    my $response = $message->response;

    if ( $self->code ) {
        return $self->make_response(code => $self->code);
    }

    unless ( $response ) {
        # assume the contact doesn't exist
        return $self->make_response(code => 2303);
    }

    # make the Info::Response object
    my %addr = (
        street => [ $response->address->address1, $response->address->address2 || ()],
        city   => $response->address->city,        
        cc     => $response->address->cc,
    );
    
    $addr{sp} = $response->address->region   if defined $response->address->region; # state or province
    $addr{pc} = $response->address->postcode if defined $response->address->postcode;
    
    # The SRS local number field can contain anything alphanumeric. We grab anything numeric from the beginning
    #  of the string (including spaces, dashes, etc. which we strip out) and call that part of the phone number
    #  anything after that goes into the 'x' field of the E164 object.
    $response->phone->subscriber =~ m{(^[\d\s\-\.]*)(.*?)$};
    my ($local_number, $x) = ($1, $2);
    
    # If we didn't get anything assigned to either field, our regex could be wrong. Just stick the whole thing in $x
    $x = $response->phone->subscriber unless $local_number || $x;
    
    # Strip out anything non-numeric from $local_number
    $local_number =~ s/[^\d]//g;    

    my $r = XML::EPP::Contact::Info::Response->new(
        id => $response->handle_id,
        # roid => ?,
        # status => [ $self->message->status ],
        postal_info => [ XML::EPP::Contact::PostalInfo->new(
            name => $response->name,
            # org => ,
            addr => XML::EPP::Contact::Addr->new(
                %addr,
            ),
        ) ],
        voice => XML::EPP::Contact::E164->new(
            content => "+" . $response->phone->cc . "." . $response->phone->ndc . $local_number,
            ($x ? (x => $x) : ()),
        ),
        #fax => XML::EPP::Contact::E164->new(
        #    content => $response->phone->cc . $response->phone->ndc . $response->phone->subscriber,
        #),
        # fax => ,
        email => $response->email,
    );

    return $self->make_response(
        code => 1000,
        payload => $r,
    );
}

1;
