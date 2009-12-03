#!/usr/bin/perl -w
#
# test script for validation and load/dump between Perl/Moose and XML
# for complete messages and fragments described in RFC37^H^H49^H^H5730
# (EPP and EPP common)

use Test::More;
use strict;
use FindBin qw($Bin $Script);
use File::Find;
use Scriptalicious;
use SRS::EPP::Message;
use YAML;

(my $test_dir = "$Bin/$Script") =~ s{\.t$}{};
my @tests;
my $grep;
getopt("test-grep|t=s" => \$grep );
find(sub {
	     if ( m{\.xml$} && (!$grep||m{$grep}) ) {
		     push @tests, $File::Find::name;
	     }
     }, $test_dir);

plan tests => @tests * 3;

for my $test ( sort @tests ) {
	(my $test_name = $test) =~ s{^\Q$test_dir\E/}{};
	open XML, "<$test";
	binmode XML, ":utf8";
	my $xml = do {
		local($/);
		<XML>;
	};
	close XML;
	start_timer;
	my $object = eval { SRS::EPP::Message->parse( $xml ) };
	my $time = show_elapsed;
	my $ok = ok($object&&$object->epp, "$test_name - parsed OK ($time)");
	if ( !$ok ) {
		diag("exception: $@");
	}
	if ( $ok and $VERBOSE>0) {
		diag("read: ".Dump($object->epp));
	}
 SKIP: {
		skip "didn't parse", 2 unless $ok;
		start_timer;
		my $r_xml = eval { $object->to_xml };
		$time = show_elapsed;
		ok($r_xml, "$test_name - emitted OK ($time)")
			or do {
				diag("exception: $@");
				skip "got an exception", 1;
			};
		if ($VERBOSE>0) {
			diag("xml: ".$r_xml);
		}
		my $recycled = eval { SRS::EPP::Message->parse($r_xml) };
		is_deeply($recycled, $object,
			  "round-tripped to XML and back")
			or do {
				diag("First round: ".Dump($object));
				diag("Second round: ".Dump($recycled));
			};
	}
}

# Copyright (C) 2009  NZ Registry Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2.0 or later.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Artistic License 2.0 for more details.
#
# You should have received a copy of the Artistic License the file
# COPYING.txt.  If not, see
# <http://www.perlfoundation.org/artistic_license_2_0>
