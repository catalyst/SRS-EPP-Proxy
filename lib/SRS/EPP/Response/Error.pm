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

with 'MooseX::Log::Log4perl::Easy';

use SRS::EPP::Response::Error::Map qw(map_error);

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
	
around 'BUILDARGS' => sub {
    my $orig = shift;
    my $class = shift;
    my %params = @_;
    
    # If they haven't provided a code, we look at the exception they gave us, and try to
    #  work it out ourselves. We can only do this if the exception is a XML::SRS::Error
    # TODO: we possibly want to do this (error mapping) even if they *do* provide a code
    #  or at least make the interface a bit clearer - right now it's kind of an obscure
    #  set of parameters that triggers this (useful) magic
    unless ($params{code}) {        
        confess "Must provide either a code or exception" unless $params{exception};
        
        $params{exception} = [$params{exception}] unless ref $params{exception} eq 'ARRAY';
        
        confess "Can only derive code if provided exception isa XML::SRS::Error: " . Dumper (\%params) 
            if grep { ! blessed($_) || ! $_->isa('XML::SRS::Error') } @{ $params{exception} };

        my @mapped_exceptions;            
        foreach my $except (@{ $params{exception} }) {
            my %result = map_error($except);
            
            push @mapped_exceptions, @{$result{errors}};
             
            # Use the code for the first error we find. The rfc is unclear on what we should use
            #  (in fact, they probably never thought of it)
            $params{code} ||= $result{code};
        }

        # Overwrite the exception with the XML::EPP::Error(s)        
        $params{exception} = \@mapped_exceptions;        
    }
        
    return $class->$orig(%params);    
};

around 'build_response' => sub {
	my $orig = shift;
	my $self = shift;

	my $message = $self->$orig(@_);
	my $result = $message->message->result;

	my $bad_node = $self->bad_node;
	my $except = $self->exception;

	given ($except) {
        when (ref $_ eq 'ARRAY') {
            foreach my $error (@$_) {
                $result->[0]->add_error($error);
            }
        }
		when (!blessed($_)) {
		    my $reason = ref $_ ? Dumper $_ : $_;
		    $reason =~ s/at (?:.+?) line \d+//mg;
		    my $error = XML::EPP::Error->new(
				value => 'Unknown',
				reason => $reason,
			);
			$result->[0]->add_error($error);
		}
		when ($_->isa("PRANG::Graph::Context::Error") ) {
			use YAML;
			my $xpath = $except->xpath;

			my $message = $except->message;

			my @lines = split /\n/, $message;			
			
			my $reason = "XML validation error at $xpath";
			if ( $lines[0] =~ m{Validation failed for '.*::(\w+Type)' failed with value (.*) at}) {
				$reason .= "; '$2' does not meet schema requirements for $1";
			}
			elsif ($lines[0] =~ m{Attribute \(.+?\) does not pass the type constraint}) {
			    # Nothing else needed in the reason
			}
			else {
			    # Catch-all - return the first line.
			    # TODO: possibly too much information... might pay to remove this before go-live
			    $lines[0] =~ m{^(.+?)(?: at .+? line \d+)?$}; 
			    $reason .= "; $1";
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
		when ($_->isa("XML::EPP::Error")) {
            $result->[0]->add_error($except);   
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
