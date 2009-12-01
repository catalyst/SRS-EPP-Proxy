#!/usr/bin/perl -w
#
# test script for validation and load/dump between Perl/Moose and XML
# for complete messages and fragments described in RFC4930 (EPP and
# EPP common)

use Test::More no_plan;
use strict;

# of particular note: these stateful EPP messages are never converted
# to the stateless SRS protocol; so they will not be covered by later
# tests and tests must be particularly thorough.

#    - Hello / Greeting
#    - logout

BEGIN {
	use_ok("SRS::EPP::Command");
}

# an example minimal-ish login message (minimal as in, no XML
# namespaces, etc).  presumably if they supply
# <objURI>urn:ietf:params:xml:ns:host-1.0</objURI> as a svcs we have
# to put an error/warning in the response.
my $login_request = <<XML;
<epp>
  <command>
    <login>
      <clID>123</clID>
      <pw>SecureThis! orz</pw>
      <options>
        <version>1.0</version>
        <lang>en-NZ</lang>
      </options>
      <svcs>
        <objURI>urn:ietf:params:xml:ns:epp-1.0</objURI>
        <objURI>urn:ietf:params:xml:ns:contact-1.0</objURI>
        <objURI>urn:ietf:params:xml:ns:domain-1.0</objURI>
      </svcs>
    </login>
  </command>
</epp>
XML

my $login_object = SRS::EPP::Message->parse(
	$login_request,
       );

isa_ok($login_object, "SRS::EPP::Command",
       "new login request");

use YAML;

diag(Dump $login_object);
use Scriptalicious;

use Time::HiRes qw(time);
my $start = time;
my $count;
while ( time - $start < 1 ) {
	SRS::EPP::Message->parse($login_request);
	$count++;
}
my $elapsed = time - $start;
diag("Parsed $count login requests in ".Scriptalicious::time_unit($elapsed)
	     ." (".sprintf("%.1f", $count/$elapsed)." per second)");

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
