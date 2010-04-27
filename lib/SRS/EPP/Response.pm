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

package SRS::EPP::Response;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
extends 'SRS::EPP::Message';

use SRS::EPP::SRSResponse;

use XML::EPP;
has "+message" =>
	isa => "XML::EPP",
	;

has "client_id" =>
	is => "ro",
	isa => "XML::EPP::trIDStringType",
	;

has "server_id" =>
	is => "ro",
	isa => "XML::EPP::trIDStringType",
	lazy => 1,
	default => sub {
		my $self = shift;
		$self->session->new_server_id;
	},
	;

method notify( SRS::EPP::SRSResponse @rs ) {
	my $result;
	if ( my $server_id = eval {
		$result = $rs[0]->message;
		$result->fe_id.",".$result->unique_id
	} ) {
		$self->server_id($server_id);
	}
}

has 'code' =>
	is => 'ro',
	isa => "XML::EPP::resultCodeType",
	;

has "session" =>
	is => "rw",
	isa => "SRS::EPP::Session",
	weak_ref => 1,
	;

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

SRS::EPP::Response - EPP XML

=head1 SYNOPSIS

 ...

=head1 DESCRIPTION

This is a base class for all EPP responses.

=head1 SEE ALSO

L<SRS::EPP::Message>

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
