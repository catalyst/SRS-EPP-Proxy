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

package SRS::EPP::Message;
use Moose;

has 'xml' =>
	is => "rw",
	;

has 'message' =>
	is => "ro",
	handles => [qw(to_xml)],
	;

has 'error' =>
	is => "rw",
	;

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

SRS::EPP::Message - abstract type for a single message particle

=head1 SYNOPSIS

 my $msg = SRS::EPP::Message->new(
     message => $object,
     xml => $xml,
     error => $message,
     );
 # convert a message to XML
 $message->to_xml;

=head1 DESCRIPTION

This class is a common ancestor of EPP commands and responses, as well
as SRS requests and responses.  Currently the only method that all of
these implement is conversion to XML; however parsing is likely to
follow.

=head1 SEE ALSO

L<SRS::EPP::Command>, L<SRS::EPP::Response>

=for thought

What space should we stick SRS messages under?  I reckon maybe plain
SRS::Request:: and SRS::Response::, and subclass them...

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
