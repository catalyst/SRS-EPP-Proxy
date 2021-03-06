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

package SRS::EPP::Response::Error;
use Moose;
extends 'SRS::EPP::Response';

has 'exception' =>
	is => 'ro',
	;

has 'bad_node' =>
	is => "rw",
	isa => "XML::LibXML::Node",
	;

has '+server_id' =>
	required => 1,
	;

after 'message_trigger' => sub {
	my $self = shift;
	my $bad_node = $self->bad_node;
	my $result = $self->message->message->result;
	if ( my $except = $self->exception ) {
		# permit validation errors to be returned.
		if ( blessed $except and
			     $except->isa("PRANG::Graph::Context::Error") ) {
			my $error = XML::EPP::Error->new(
				value => $except->node,
				reason => "XML validation error at "
					.$except->xpath."; "
						.$except->message,
				);
			$result->add_error($error);
		}
	}
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

SRS::EPP::Response::Error - EPP exception/error response class

=head1 SYNOPSIS

 #... in a SRS::EPP::Command subclass' ->process() handler...
 return SRS::EPP::Response::Error->new
        (
             id => "XXXX",
             extra => "...",
        );

=head1 DESCRIPTION

This module handles generating errors; the information these can hold
is specified in RFC3730 / RFC4930.

=head1 SEE ALSO

L<SRS::EPP::Response>, L<SRS::EPP::Command>

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
