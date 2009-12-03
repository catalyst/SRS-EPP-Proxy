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

use Moose::Role;
use MooseX::Method::Signatures;

use XML::EPP;
use PRANG::Marshaller;

has 'epp' =>
	is => "rw",
	isa => "XML::EPP",
	handles => [ qw(to_xml) ],
	;

sub parse {
	my $class = shift;
	my $xml = shift;
	my $epp = PRANG::Marshaller->get("XML::EPP")
		->parse($xml);
	my $subclass = $epp->is_command ?
		"SRS::EPP::Command" : "SRS::EPP::Response";
	if (! eval{ $subclass->can("new") } ) {
		eval "use $subclass";
	}
	return $subclass->new( epp => $epp );
}

1;

__END__

=head1 NAME

SRS::EPP::Message - EPP XML

=head1 SYNOPSIS

 # convert a message to XML
 my $xml = $message->to_xml;

 # parse a message, see what we get!
 my $object = SRS::EPP::Message->parse( $xml );

=head1 DESCRIPTION

This class is a role digested by message classes - EPP commands and
responses.

=head1 SEE ALSO

L<SRS::EPP::Command>, L<SRS::EPP::Response>

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
