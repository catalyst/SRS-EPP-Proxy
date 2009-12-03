#!/usr/bin/perl -w

use Scriptalicious;
use strict;
use 5.010;
use File::Path;
use Fatal qw(:void open);

getopt;

my $input = shift;
$input =~ m{rfc\d+\.txt$} or abort "bad input";

my $output_dir = shift or abort "no output dir specified";
$output_dir =~ s{\.t$}{};
$output_dir =~ s{/rfc-examples/?$}{};
if ( ! -f "$output_dir.t" ) {
	abort "no such test script $output_dir.t; refusing to run";
}
$output_dir .= "/rfc-examples";
( -d $output_dir ) || mkpath($output_dir);

open (my $rfc, $input);
my $state = "body";
my $last_line;
my ($frag_num, @frag, $frag_start) = (0);
my $emit_frag = sub {
	my $ll = $last_line;
	$ll =~ s{Example}{};
	$ll =~ s{[^\s\w]}{}g;
	$ll =~ s{\s+}{-}g;
	$ll =~ s{--+}{-}g;
	$ll =~ s{^-|-$}{}g;
	$ll = lc($ll);
	my $filename = sprintf("%.2d-line$frag_start-$ll.xml", $frag_num);
	open XML, ">$output_dir/$filename";
	print XML @frag;
	close XML;
	say "wrote ".@frag." lines to $output_dir/$filename";
	@frag=();
};
while (my $line = <$rfc>) {
	given ($state) {
		when ("body") {
			given($line) {
				when(/^\s+[SC]:(.*)/s) {
					$state = "xml-frag";
					$frag_num++;
					push @frag, $1;
					$frag_start = $.;
				}
				when(/^\s+(\S.*)/) {
					$last_line = $1;
				}
			}
		}
		when ("xml-frag") {
			given($line) {
				when(/^\s+[SC]:(.*)/s) {
					push @frag, $1;
				}
				when(!/\S/) {
					# nothing..
				}
				when(/^\s+(\S)|^\d+\./) {
					$emit_frag->();
					$state = "body";
				}
			}
		}
	}
}
$emit_frag->() if @frag;
say "found ".(0+$frag_num)." examples in $. lines of $input";
close $rfc;

=head1 NAME

rfc-eg-sucker - suck examples from EPP RFCs

=head1 SYNOPSIS

 rfc-eg-sucker path/to/rfcNNNN.txt output-dir

=head1 DESCRIPTION

Grabs all the XML from the examples, and throws them into an
'rfc-examples' directory under 'output-dir' (you can just pass the
name of a .t file in if you like)

=cut
