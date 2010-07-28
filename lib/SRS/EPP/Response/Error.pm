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

use 5.010;

package SRS::EPP::Response::Error;
use Moose;
use MooseX::StrictConstructor;
use Data::Dumper;
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

around 'build_response' => sub {
	my $orig = shift;
	my $self = shift;

	my $message = $self->$orig(@_);
	my $result = $message->message->result;

	my $bad_node = $self->bad_node;
	my $except = $self->exception;
	given ($except) {
		when (!blessed($_)) {
		    my $reason = ref $_ ? Dumper $_ : $_;
		    my $error = XML::EPP::Error->new(
				value => '???',
				reason => $reason,
			);
			$result->[0]->add_error($error);
		}
		when ($_->isa("PRANG::Graph::Context::Error") ) {
			use YAML;
			my $xpath = $except->xpath;
			my $message = $except->message;
			my $reason = "XML validation error at $xpath";
			if ( $message =~ m{Validation failed for '.*::(\w+Type)' failed with value (.*) at}) {
				$reason .= "; '$2' does not meet schema requirements for $1";
			}
			my $error = XML::EPP::Error->new(
				value => $except->node,
				reason => $reason,
				);
			$result->[0]->add_error($error);
		}
		when ($_->isa("XML::LibXML::Error") ) {
			while ( $except ) {
				my $error = XML::EPP::Error->new(
					value => $except->context || "(n/a)",
					reason => $except->message,
					);
				$result->[0]->add_error( $error );
				# though called '_prev', this function
				# is documented.
				$except = $except->_prev;
			}
		}
		when ($_->isa("XML::SRS::Error")) {
			my $new_result = $message->message->result->clone(
				map_error($except)
				);
			$message->message->result($new_result);
		}
	}
	$message;
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
