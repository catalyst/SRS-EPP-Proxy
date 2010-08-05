package SRS::EPP::Command::Update::Domain;

use Moose;
extends 'SRS::EPP::Command::Update';
use MooseX::Method::Signatures;
use Crypt::Password;

use XML::SRS::Server;
use XML::SRS::Server::List;

my $allowed = {
    action => { add => 1, remove => 1 },
};

# for plugin system to connect
sub xmlns {
    return XML::EPP::Domain::Node::xmlns();
}

has 'state' =>
    'is' => 'rw',
    'isa' => 'Str',
    'default' => 'EPP-DomainUpdate'
    ;

# we onyl ever enter here once, so we know what state we're in
method process( SRS::EPP::Session $session ) {
    $self->session($session);

    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # firstly check that we have at least one of add, rem and chg
    unless ( $payload->add or $payload->remove or $payload->change ) {
        return $self->make_response(code => 2002);
    }

    # we're not going to do anything with Status additions or removals
    if ( ( $payload->add and $payload->add->status )
         or ( $payload->remove and $payload->remove->status ) ) {
        return $self->make_response(code => 2307);
    }

    # if they want to add/remove a nameserver, then we need to hit the SRS
    # first to find out what they are currently set to
    if ( ( $payload->add and $payload->add->ns )
         or ( $payload->remove and $payload->remove->ns ) ) {

        # remember the fact that we're doing a domain details query first
        $self->state('SRS-DomainDetailsQry');

        # need to do a DomainDetailsQry
        return (
            XML::SRS::Domain::Query->new(
                domain_name_filter => $payload->name,
                field_list => XML::SRS::FieldList->new(
                    name_servers    => 1,
                ),
            )
        );
    }

    # ok, we have all the info we need, so create the request
    my $request = $self->make_request($message, $payload);
    $self->state('SRS-DomainUpdate');
    return $request;
}


method notify( SRS::EPP::SRSResponse @rs ) {
    # original payload
    my $epp = $self->message;
    my $message = $epp->message;
    my $payload = $message->argument->payload;

    # response from SRS (either a DomainDetailsQry or a DomainUpdate)
    my $res = $rs[0]->message->response;

    if ( $self->state eq 'SRS-DomainDetailsQry' ) {
        # we have just asked for the DomainDetailsQry so we are doing an
        # add/remove of a nameserver
        # my @ns = map { $_->fqdn } @{$res->nameservers->nameservers};
        my %ns;
        foreach my $ns ( map { $_->fqdn } @{$res->nameservers->nameservers} ) {
            $ns{$ns} = 1;
        }

        # check what the user wants to do (it's either an add, rem or both)
        # do the add first
        if ( $payload->add and $payload->add->ns ) {
            my $add_ns = $payload->add->ns->host_objs;

            # loop through and add them
            foreach my $ns ( @$add_ns ) {
                $ns{$ns} = 1;
            }
        }
        # now do the remove
        if ( $payload->remove and $payload->remove->ns ) {
            my $rem_ns = $payload->remove->ns->host_objs;

            # loop through and remove them
            foreach my $ns ( @$rem_ns ) {
                delete $ns{$ns};
            }
        }

        my @ns_list = sort keys %ns;

        # so far all is good, now send the DomainUpdate request to the SRS
        my $request = $self->make_request($message, $payload, \@ns_list);
        $self->state('SRS-DomainUpdate');
        return $request;
    }
    elsif ( $self->state eq 'SRS-DomainUpdate' ) {
        # if we get no response, then it's likely the domain name doesn't exist
        # ie. the DomainNameFilter didn't match anything
        unless ( defined $res ) {
            # Object does not exist
            return $self->make_response(code => 2303);
        }

        # everything looks ok, so let's return a successful message
        return $self->make_response(code => 1000);
    }
}

sub make_request {
    my ($self, $message, $payload, $new_nameservers) = @_;

    # the first thing we're going to check for is a change to the registrant
    my %contacts;
    if ( $payload->change ) {
        if ( my $registrant = $payload->change->registrant ) {
            # changing the registrant, so let's remember that
            $contacts{contact_registrant} = _make_contact($registrant);
        }
    }

    # Get the contacts (if any)
    for my $contact (qw/admin technical/) { 
        my $contact_new = _extract_contact( $payload, 'add', $contact );
        my $contact_old = _extract_contact( $payload, 'remove', $contact );
        
        my $new_contact = _make_contact($contact_new, $contact_old);
        
        $contacts{'contact_' . $contact} = $new_contact if defined $new_contact; 
    }
            
    # now set the nameserver list
    my $ns_list;
    if ( defined $new_nameservers and @$new_nameservers ) {
        $ns_list = XML::SRS::Server::List->new(
            nameservers => [ map { XML::SRS::Server->new( fqdn => $_ ) } @$new_nameservers ],
        );
    }

    return XML::SRS::Domain::Update->new(
        filter => [ $payload->name() ],
        %contacts,
        ( $ns_list ? ( nameservers => $ns_list ) : () ),
        action_id => $message->client_id || sprintf('auto.%x', time()),
    );
}

sub _make_contact {
    my ($new, $old) = @_;

    # if we have a new contact, replace it (independent of $old)
    return XML::SRS::Contact->new( handle_id => $new )
        if $new;

    # return an empty contact element so that the handle gets deleted
    return XML::SRS::Contact->new()
        if $old;

    # if neither of the above, there is nothing to do
    return;
}

sub _extract_contact {
    my ($payload, $action, $type ) = @_;

    # check the input
    die q{Program error: '$action' should be 'add' or 'remove'}
        unless $allowed->{action}{$action};

    $type = 'tech' if $type eq 'technical';

    # check that action is there
    return unless $payload->$action;

    my $contacts = $payload->$action->contact;
    foreach my $c ( @$contacts ) {
        return $c->value if $c->type eq $type;
    }
    return;
}

1;