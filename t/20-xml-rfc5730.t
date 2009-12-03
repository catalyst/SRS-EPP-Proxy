#!/usr/bin/perl -w
#
# test script for validation and load/dump between Perl/Moose and XML
# for complete messages and fragments described in RFC37^H^H49^H^H5730
# (EPP and EPP common)

use Test::More no_plan;
use strict;

# of particular note: these stateful EPP messages are never converted
# to the stateless SRS protocol; so they will not be covered by later
# tests and tests must be particularly thorough.

#    - Hello / Greeting
#    - logout

BEGIN {
	use_ok("SRS::EPP::Message");
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

use Scriptalicious;

start_timer;
my $login_object = SRS::EPP::Message->parse(
	$login_request,
       );
diag("That took ".show_elapsed);

isa_ok($login_object, "SRS::EPP::Command",
       "new login request");

diag("Login request is:".Dump($login_object));

is(eval{$login_object->epp->message->object->pw->content}, "SecureThis! orz",
   "Seemed to parse the object OK");
diag($@) if $@;

my $xml = $login_object->to_xml;
use FindBin qw($Bin);

# Couldn't get XML::LibXML::Schema to work with a schema in two parts
#my $schema = XML::LibXML::Schema->new( location => "$Bin/../lib/XML/EPP/epp-1.0.xsd" );
#my $parser = XML::LibXML->new;
#my $document = $parser->parse_string($xml);
diag("serialized to xml: ".$xml);

my $login_object_2 = SRS::EPP::Message->parse(
	$xml,
       );

is_deeply($login_object, $login_object_2,
	  "round-trip to XML and back yielded no difference")
	or do {
		diag("We saw back: ".Dump($login_object_2));
	};

use YAML;

my @mcs = Class::MOP::get_all_metaclass_instances;
#for (@mcs) { $_->make_immutable if $_->can("make_immutable") }
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
