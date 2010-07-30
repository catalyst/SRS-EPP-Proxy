

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
	my @errors;
	for my $response ( @rs ) {
		my $domain = $response->message->response;
			
		if ($domain->isa('XML::SRS::Error')) {
        	push @errors, $domain;
		}
		else {		
    		my $name_status = XML::EPP::Domain::Check::Name->new(
    			name => $domain->name,
    			available => ($domain->status eq "Available"
    					      ? 1 : 0 ),
    	    );
    		my $result = XML::EPP::Domain::Check::Status->new(
    			name_status => $name_status,
    	    );
    	    
    	    push @response_items, $result;
		}
	}

    # We return an error if *any* of the domains is invalid.
    #  It's unclear whether this is correct behaviour according to the RFC
    #  It's possible the schema supports both resData and error messages,
    #   however, we'd need to refactor a bit to acheive this.
    if (@errors) {
        return $self->make_error_response(
            \@errors,
        );
    }
    else {
    	my $r = XML::EPP::Domain::Check::Response->new(
    		items => \@response_items,
    	       );
    
    	return $self->make_response(
    		code => 1000,
    		payload => $r,
    	       );
    }
};

1;
