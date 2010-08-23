package SRS::EPP::Command::Info::Contact;

use Moose;
extends 'SRS::EPP::Command::Info';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Contact;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

use XML::EPP::Contact::Info::Response;
use XML::EPP::Contact::PostalInfo;
use XML::EPP::Contact::Addr;
use XML::EPP::Contact::Status;

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

sub zero_pad {
	my $registrar_id = shift;
	sprintf("%03d", $registrar_id);
}

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

    # Compare the contact's creation date against the audit time, to tell us if it's been updated
    my $contact_updated = 0;
    if ($response->created_date->timestamptz ne $response->audit->when->begin->timestamptz) {
       $contact_updated = 1;
    }

    my $r = XML::EPP::Contact::Info::Response->new(
        id => $response->handle_id,
        postal_info => [ XML::EPP::Contact::PostalInfo->new(
            name => $response->name,
            addr => XML::EPP::Contact::Addr->new(
                %addr,
            ),
        ) ],
        roid => substr(md5_hex($response->registrar_id . $response->handle_id), 0, 12) . '-CON',
        ($response->phone ? (voice => $self->_translate_phone_number($response->phone)) : ()),
        ($response->fax   ? (fax   => $self->_translate_phone_number($response->fax))   : ()),
        email => $response->email,
        created => $response->created_date->timestamptz,
        creator_id => zero_pad($response->registrar_id),
        status => [XML::EPP::Contact::Status->new(status => 'ok')],
        ($contact_updated ?
            (
                updated_by_id => zero_pad($response->audit->registrar_id),
                updated => $response->audit->when->begin->timestamptz,
            )
            : ()
        ),
    );

    return $self->make_response(
        code => 1000,
        payload => $r,
    );
}

# Translate a SRS number to an EPP number
sub _translate_phone_number {
    my $self = shift;
    my $srs_number = shift;

    # The SRS local number field can contain anything alphanumeric. We grab anything numeric from the beginning
    #  of the string (including spaces, dashes, etc. which we strip out) and call that part the phone number.
    #  Anything after that goes into the 'x' field of the E164 object.
    $srs_number->subscriber =~ m{(^[\d\s\-\.]*)(.*?)$};
    my ($local_number, $x) = ($1, $2);

    # If we didn't get anything assigned to either field, our regex could be wrong. Just stick the whole thing in $x
    $x = $srs_number->subscriber unless $local_number || $x;

    # Strip out anything non-numeric from $local_number
    $local_number =~ s/[^\d]//g;

    return XML::EPP::Contact::E164->new(
        content => "+" . $srs_number->cc . "." . $srs_number->ndc . $local_number,
        ($x ? (x => $x) : ()),
    );
}

1;
