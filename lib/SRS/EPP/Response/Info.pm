
package SRS::EPP::Response::Info;
use Moose;
extends 'SRS::EPP::Response';
use Data::Dumper;

has "+message" =>
	lazy => 1,
	default => \&make_response,
	;

has 'payload' =>
	is => 'rw',
	isa => 'XML::EPP::Plugin', # XML::EPP::Plugin
	required => 1,
	;

sub make_response {
	my $self = shift;

    my $server_id = $self->server_id;
    my $client_id = $self->client_id;

    my $tx_id;
    if ( $server_id ) {
        $tx_id = XML::EPP::TrID->new(
            server_id => $server_id,
            ($client_id ? (client_id => $client_id) : () ),
            );
    }

    my $msg = $self->extra;
    my $result = XML::EPP::Result->new(
        ($msg ? (msg => $msg) : ()),
        # msg => '',
        code => $self->code,
    );

    my $xml_epp = XML::EPP->new(
        message => XML::EPP::Response->new(
            result => [$result],
            response => XML::EPP::SubResponse->new(
                payload => $self->payload,
            ),
            ($tx_id ? (tx_id => $tx_id) : () ),
        ),
    );
    return $xml_epp;
}

1;
