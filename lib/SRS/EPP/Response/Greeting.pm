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

package SRS::EPP::Response::Greeting;
use Moose;
extends 'SRS::EPP::Response';

sub as_xml {
	return 'This is where we generate the greeting message';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

SRS::EPP::Message::Greeting - EPP XML Greeting message

=head1 SYNOPSIS

 return SRS::EPP::Message::Greeting->new;

=head1 DESCRIPTION

This module handles generating the EPP XML greeting

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