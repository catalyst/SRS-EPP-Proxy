package SRS::EPP::Common::Contact;

use Moose::Role;

requires 'make_response';

# Check if an epp contact has certain field we don't support
#  Return an error message if they do, nothing if it's valid
sub validate_epp_contact {
    my $self    = shift;
    my $contact = shift;

    my $epp_postal_info = $contact->postal_info();
    if ( $epp_postal_info && scalar @$epp_postal_info != 1 ) {

        # The SRS doesn't support the US's idea of i18n.  That is
        # that ASCII=international, anything else=local.
        # Instead, well accept either form of postalinfo, but throw an
        # error if they try to provide both types (because the SRS can't
        # have two translations for one address)
        return $self->make_response(
            Error => (
                code      => 2306,
                exception => XML::EPP::Error->new(
                    value  => '',
                    reason => 'Only one postal info element per contact supported',
                ),
            )
        );
    }
    my $postalInfo = $epp_postal_info->[0];
    
    return unless $postalInfo;

    # The SRS doesn't have a 'org' field, we don't want to lose info, so
    if ( $postalInfo->org ) {
        return $self->make_response(
            Error => (
                code      => 2306,
                exception => XML::EPP::Error->new(
                    value  => $postalInfo->org,
                    reason => 'org field not supported',
                ),
            )
        );
    }
    
    # SRS requires at least one address line, but not more than 2. Reject request if they send 0
    #  or 3 street lines
    my $street_lines = $postalInfo->addr->street;
    if (! $street_lines || scalar @$street_lines < 1 || @$street_lines > 2) {
        return $self->make_response(
            Error => (
                code      => 2306,
                exception => XML::EPP::Error->new(
                    value  => '',
                    reason => 'At least 1 and no more than 2 street lines must be supplied in the address',
                ),
            )
        );        
    }

    return;
}

# Turn an epp address into an srs address
sub translate_address {
    my $self = shift;
    my $epp_address = shift;

    my $street  = $epp_address->street();
    my $address = XML::SRS::Contact::Address->new(
        address1 => $street->[0],
        ( $street->[1] ? (address2 => $street->[1]) : () ),
        city     => $epp_address->city,
        ( $epp_address->sp ? ( region => $epp_address->sp ) : () ),
        cc => $epp_address->cc,
        ( $epp_address->pc ? ( postcode => $epp_address->pc ) : () ),
    );
        
    return $address;
}

1;
