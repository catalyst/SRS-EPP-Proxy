# vim: filetype=perl:noexpandtab:ts=3:sw=3
#
# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

package SRS::EPP::Command;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

extends 'SRS::EPP::Message';

use XML::EPP;
use XML::SRS::Error;

has "+message" =>
	isa => "XML::EPP",
	;

use Module::Pluggable search_path => [__PACKAGE__];

sub rebless_class {
	my $object = shift;
	our $map;
	if ( !$map ) {
		$map = {
			map {
				$_->can("match_class") ?
					( $_->match_class => $_ )
						: ();
			}# map { print "rebless_class checking plugin $_\n"; $_ }
				grep m{${\(__PACKAGE__)}::[^:]*$},
				__PACKAGE__->plugins,
		};
	}
	$map->{ref $object};
}

sub action_class {
	my $action = shift;
	our $action_classes;
	if ( !$action_classes ) {
		$action_classes = {
			map {
				$_->can("action") ?
					($_->action => $_)
						: ();
			}# map { print "action_class checking plugin $_\n"; $_ }
				grep m{^${\(__PACKAGE__)}::[^:]*$},
			__PACKAGE__->plugins,
		};
	}
	$action_classes->{ $action };
}

sub REBLESS {

}

sub BUILD {
	my $self = shift;
	if ( my $epp = $self->message ) {
		my $class;
		$class = rebless_class( $epp->message );
		if ( !$class and $epp->message and
			     $epp->message->can("action") ) {
			$class = action_class($epp->message->action);
		}
		if ( $class ) {
			#FIXME: use ->meta->rebless_instance
			bless $self, $class;
			$self->REBLESS;
		}
	}
}

method simple() { 0 }
method authenticated() { 1 }
method done() { 1 }

BEGIN {
	class_type "SRS::EPP::Session";
	class_type "SRS::EPP::SRSResponse";
}

has 'session' =>
	is => "rw",
	isa => "SRS::EPP::Session",
	weak_ref => 1,
	;

has 'server_id' =>
	is => "rw",
	isa => "XML::EPP::trIDStringType",
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->session->new_server_id;
	}
	;

BEGIN {
	class_type "SRS::EPP::Session";
}

# process a simple message - the $session is for posting back events
method process( SRS::EPP::Session $session ) {
	$self->session($session);

	# default handler is to return an unimplemented message
	return $self->make_response(code => 2101);
}

method notify( SRS::EPP::SRSResponse @rs ) {
	my $result;
	if ( my $server_id = eval {
		$result = $rs[0]->message;
		$result->fe_id.",".$result->unique_id
	} ) {
		$self->server_id($server_id);
	}
}

sub make_response {
	my $self = shift;
	my $type = "SRS::EPP::Response";
	if ( @_ % 2 ) {
		$type = shift;
		$type = "SRS::EPP::Response::$type" if $type !~ /^SRS::/;
	}
	my %fields = @_;
	$fields{client_id} ||= $self->client_id if $self->has_client_id;
	$fields{server_id} ||= $self->server_id;
	$type->new(
		%fields,
		);
}

method make_error_response( XML::SRS::Error|ArrayRef[XML::SRS::Error] $srs_error ) {
    return SRS::EPP::Response::Error->new(
        server_id => $self->server_id,
        exception => $srs_error,
    );
}

has "client_id" =>
	is => "rw",
	isa => "XML::EPP::trIDStringType",
	predicate => "has_client_id",
	;

after 'message_trigger' => sub {
	my $self = shift;
	my $message = $self->message;
	if ( my $client_id = eval { $message->message->client_id } ) {
		$self->client_id($client_id);
	}
};

use Module::Pluggable
	require => 1,
	search_path => [__PACKAGE__],
	;

__PACKAGE__->plugins;

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

SRS::EPP::Command - encapsulation of received EPP commands

=head1 SYNOPSIS

  my $cmd = SRS::EPP::Command::SubClass->new
            (
               xmlschema => ...
               xmlstring => ...
            );

  my $response = $cmd->process;

=head1 DESCRIPTION

This module is a base class for EPP commands; these are messages sent
from the client to the server.

=head1 ATTRIBUTES

=over

=item xmlschema

The XML schema for this message, as a string.  (XXX - this should be a
class data variable)

=item xmlstring

The data of the message.

=back

=head1 SEE ALSO

L<SRS::EPP::Command::Login>, L<SRS::EPP::Message>,
L<SRS::EPP::Response>

=cut

# Local Variables:
# mode:cperl
# indent-tabs-mode: t
# tab-width: 8
# cperl-continued-statement-offset: 8
# cperl-brace-offset: 0
# cperl-close-paren-offset: 0
# cperl-continued-brace-offset: 0
# cperl-continued-statement-offset: 8
# cperl-extra-newline-before-brace: nil
# cperl-indent-level: 8
# cperl-indent-parens-as-block: t
# cperl-indent-wrt-brace: nil
# cperl-label-offset: -8
# cperl-merge-trailing-else: t
# End:
