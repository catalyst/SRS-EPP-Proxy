package SRS::EPP::Command::Create::Domain;

use Moose;
extends 'SRS::EPP::Command::Create';
use MooseX::Method::Signatures;
use Crypt::Password;
use SRS::EPP::Session;
use XML::EPP::Domain;
use XML::SRS::TimeStamp;
use XML::SRS::Server::List;
use XML::SRS::Server;
use XML::SRS::Contact;

# for plugin system to connect
sub xmlns {
    return XML::EPP::Domain::Node::xmlns();
}

method process( SRS::EPP::Session $session ) {
    $self->session($session);

    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # find the admin contact
    my $contacts = $payload->contact;

    # create all the contacts (using their handles)
    my $contact_registrant = XML::SRS::Contact->new( handle_id => $payload->registrant() );
    my ($contact_admin, $contact_technical);
    foreach my $contact ( @$contacts ) {
        if ( $contact->type eq 'admin' ) {
            $contact_admin = XML::SRS::Contact->new( handle_id => $contact->value );
        }
        if ( $contact->type eq 'tech' ) {
            $contact_technical = XML::SRS::Contact->new( handle_id => $contact->value );
        }
    }

    my $ns = $payload->ns->ns;
    
    # Compile list of nameservers. If any aren't hostAttr's, they must be hostObj's, which
    #  are not allowed
    my @ns_objs;
    foreach my $ns (@$ns) {
        unless ($ns->isa('XML::EPP::Domain::HostAttr')) {
            return $self->make_response(
                Error => (
                    code => 2102,
                    exception => XML::EPP::Error->new(
                        value => $ns,
                        reason => 'hostObj not supported',
                    )
                )
            );   
        }
        
        my $ips = $ns->addrs;
        
        # We reject any requests that have more than 1 ip address, as the SRS
        #  doesn't really support that (altho an ipv4 and ipv6 address are allowed)
        my %translated_ips;
        foreach my $ip (@$ips) {
            my $type = $ip->ip;
            if ($translated_ips{$type}) {
                return $self->make_response(
                    Error => (
                        code => 2102,
                        exception => XML::EPP::Error->new(
                            value => $ns->name,
                            reason => 'multiple addresses for a nameserver of the same ip version not supported',
                        )
                    )
                );
            }
            
            $translated_ips{$type} = $ip->value;
        }
        
        push @ns_objs, XML::SRS::Server->new( 
            fqdn => $ns->name,
            ($translated_ips{v4} ? (ipv4_addr => $translated_ips{v4}) : ()),
            ($translated_ips{v6} ? (ipv6_addr => $translated_ips{v6}) : ()),
        ); 
    }


    my $list = XML::SRS::Server::List->new(
        nameservers => \@ns_objs,
    );

    return XML::SRS::Domain::Create->new(
        domain_name => $payload->name(),
        term => 1, # ToDo: check this
        contact_registrant => $contact_registrant,
        contact_admin => $contact_admin,
        contact_technical => $contact_technical,
        nameservers => $list,
        action_id => $message->client_id || sprintf('auto.%x',time()),
    );
}

method notify( SRS::EPP::SRSResponse @rs ) {
    my $epp = $self->message;
    my $eppMessage = $epp->message;
    my $eppPayload = $eppMessage->argument->payload;

    my $message = $rs[0]->message;
    my $response = $message->response;

    # let's create the returned create domain response
    my $r = XML::EPP::Domain::Create::Response->new(
        name => $response->name,
        created => $response->registered_date->timestamptz,
        expiry_date => $response->billed_until->timestamptz,
    );

    return $self->make_response(
        code => 1000,
        payload => $r,
    );
}

1;
