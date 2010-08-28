package SRS::EPP::Common::Contact;

use Moose::Role;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

requires 'make_error';

BEGIN {
	class_type "XML::EPP::Contact::ChangePostalInfo";
	class_type "XML::EPP::Contact::PostalInfo";
	class_type "XML::EPP::Contact::E164";
	class_type "XML::EPP::Contact::Addr";
	subtype 'SRS::EPP::Common::Contact::PostalInfo'
		=> as join "|", "XML::EPP::Contact::ChangePostalInfo",
		"XML::EPP::Contact::PostalInfo";
}

# Check if an epp contact has certain field we don't support
#  Return an error message if they do, nothing if it's valid
method validate_contact_postal( ArrayRef[SRS::EPP::Common::Contact::PostalInfo] $epp_postal_info ) {

	if ( scalar @$epp_postal_info != 1 ) {

		# The SRS doesn't support the US's idea of i18n.  That
		# is that ASCII=international, anything else=local.
		# Instead, well accept either form of postalinfo, but
		# throw an error if they try to provide both types
		# (because the SRS can't have two translations for one
		# address)
		$self->log_error(
			"$self validating_contact_postal found "
				.@$epp_postal_info
				." contacts, wanted 1"
		);
		return $self->make_error(
			code => 2306,
			value  => '',
			reason =>
				'Only one postal info element per contact supported',
		);
	}

	my $postalInfo = $epp_postal_info->[0];

	# The SRS doesn't have a 'org' field, we don't want to lose
	# info, so
	if ( $postalInfo->org ) {
		$self->log_error(
			"$self validating_epp_contact found unsupported "
				."field organization"
		);
		return $self->make_error(
			code => 2306,
			value  => $postalInfo->org,
			reason => 'org field not supported',
		);
	}

	# SRS requires at least one address line, but not more than
	# 2; Reject request if they send 0 or 3 street lines
	my $street_lines = $postalInfo->addr->street;
	if (
		!$street_lines
		|| scalar @$street_lines < 1
		|| @$street_lines > 2
		)
	{
		$self->log_error(
			"$self validating_epp_contact found "
				.@{$street_lines||[]}
				." lines of street address, 1-2 allowed"
		);
		return $self->make_error(
			code => 2306,
			value  => '',
			reason =>
				'At least 1 and no more than 2 street lines must be supplied in the address',
		);
	}

	return;
}

method validate_contact_voice( XML::EPP::Contact::E164 $voice ) {

	if ( !$voice->content ) {
		$self->log_error(
			"$self validate_contact_voice found no phone number"
		);
		return $self->make_error(
			code => 2306,
			value => '',
			reason => 'Voice phone number cannot be blank',
		);
	}
	return;
}

# Turn an epp address into an srs address
method translate_address( XML::EPP::Contact::Addr $epp_address ) {

	my $street = $epp_address->street();
	my $address = XML::SRS::Contact::Address->new(
		address1 => $street->[0],
		( $street->[1] ? (address2 => $street->[1]) : () ),
		city => $epp_address->city,
		( $epp_address->sp ? ( region => $epp_address->sp ) : () ),
		cc => $epp_address->cc,
		( $epp_address->pc ? ( postcode => $epp_address->pc ) : () ),
	);

	return $address;
}

1;
