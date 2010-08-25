
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

method multiple_responses() { 1 }

method process( SRS::EPP::Session $session ) {
	my $epp = $self->message;
	my $payload = $epp->message->argument->payload;

	my @domains = $payload->names;

	$self->log_info(
		"$self checking domains: @domains",
	);

	return map {
		XML::SRS::Whois->new(
			domain => $_,
			full => 0,
		);
	} @domains;
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $epp = $self->message;
	my $payload = $epp->message->argument->payload;

	my @response_items;
	my @errors;
	my (@available, @unavailable);
	for my $response (@rs) {
		my $domain = $response->message->response;

		my $available = $domain->is_available;

		my $name_status = XML::EPP::Domain::Check::Name->new(
			name => $domain->name,
			available => $available,
		);
		if ($available) {
			push @available, $domain->name;
		}
		else {
			push @unavailable, $domain->name;
		}
		my $result = XML::EPP::Domain::Check::Status->new(
			name_status => $name_status,
		);

		push @response_items, $result;

	}
	if (@available) {
		$self->log_info(
			"$self: available: @available",
		);
	}
	if (@unavailable) {
		$self->log_info(
			"$self: unavailable: @unavailable",
		);
	}

	my $r = XML::EPP::Domain::Check::Response->new(
		items => \@response_items,
	);

	return $self->make_response(
		code => 1000,
		payload => $r,
	);

}

1;
