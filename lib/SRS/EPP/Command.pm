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
has "+message" =>
	isa => "XML::EPP",
	;

method simple() { 0 }
method authenticated() { 1 }

BEGIN {
	class_type "SRS::EPP::Session";
}

# process a simple message - the $session is for posting back events
method process( SRS::EPP::Session $session ) {

	# default handler is to return an unimplemented message
	return SRS::EPP::Response::Error->new(
		id => 2101,
		extra => "Sorry, command not yet implemented.",
		);
}

has "client_id" =>
	is => "ro",
	isa => "XML::EPP::trIDStringType",
	lazy => 1,
	predicate => "has_client_id",
	default => sub {
		my $self = shift;
		my $message = $self->message;
		eval { $message->message->client_id }
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
