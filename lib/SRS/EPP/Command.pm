# vim: filetype=perl:noexpandtab:ts=3:sw=3
#
# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.  You should
# have received a copy of the Artistic License the file COPYING.txt.
# If not, see <http://www.perlfoundation.org/artistic_license_2_0>

use strict;
use warnings;

use XML::LibXML;
use SRS::EPP::Response::Error;

package SRS::EPP::Message::Command;
use Moose;
extends 'SRS::EPP::Message';

has 'xmlstring' => ( is => 'ro', );

# XXX - schema is a class data item; it will be the same for many
# messages, and we only want to load schemata at compile time.
has 'xmlschema' => ( is => 'ro', );

sub process {
	my ($self) = @_;

	## validate the XML against the schema
	my $schema = XML::LibXML::Schema->new( string => $self->xmlschema() );
	eval { $schema->validate( $self->xmlstring() ); };
	if ($@) {
		return SRS::EPP::Response::Error->new(
			id    => "Failed to validate XML",
			extra => $@,
		);
	}

	## parse the XML,
	my $parser = XML::LibXML->new();
	my $doc    = $parser->parse_string( $self->xmlstring() );
	if ( !$doc ) {
		return SRS::EPP::Response::Error->new(
			id    => "Unknown Error",
			extra => "Failed to parse XML",
		);
	}

	## decide what kind of thing we have, process it
	my $node = $doc->firstChild();

	## Since we don't recognise what we have, it must be an error
	return SRS::EPP::Response::Error->new(
		id    => "Unknown Error",
		extra => "Don't know how to process a $node",
	);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

SRS::EPP::Command - base class for EPP commands (requests)

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
