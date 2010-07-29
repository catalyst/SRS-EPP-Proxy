

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

method process( SRS::EPP::Session $session ) {
	my $epp = $self->message;
	my $payload = $epp->message->argument->payload;

	my @domains = $payload->names;

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
	for my $response ( @rs ) {
		my $domain = $response->message->response;
		
		if ($domain->isa('XML::SRS::Error')) {
		    # We return an error if *any* of the domains is invalid.
		    #  This is probably correct behaviour, according to the rfc
		    # TODO: just returning blanket error code at the moment...
        	return $self->make_response(
        		code => 2306,
        	);
		}
		
		my $name_status = XML::EPP::Domain::Check::Name->new(
			name => $domain->name,
			available => ($domain->status eq "Available"
					      ? 1 : 0 ),
		       );
		my $check_status = XML::EPP::Domain::Check::Status->new(
			name_status => $name_status,
		       );
		push @response_items, $check_status;
	}

	my $r = XML::EPP::Domain::Check::Response->new(
		items => \@response_items,
	       );

	# from SRS::EPP::Response::Check
	return $self->make_response(
		code => 1000,
		payload => $r,
	       );
};

1;
