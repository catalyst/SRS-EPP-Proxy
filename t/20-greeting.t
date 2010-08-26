#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

use_ok('SRS::EPP::Response::Greeting');

XML::EPP::register_obj_uri(
	qw/urn:ietf:params:xml:ns:epp:domain-1.0 urn:ietf:params:xml:ns:epp:contact-1.0/
);

my $resp = SRS::EPP::Response::Greeting->make_greeting;

my $message = $resp->message;

is($message->server_name, 'localhost', "Servername set to the default");

my $services = $message->services;

is($services->lang->[0], 'en', "English supported");

is($message->dcp->access->access, 'personalAndOther', "DCP access set correctly");

is($services->objURI->[0], 'urn:ietf:params:xml:ns:epp:domain-1.0', "Correct objURI 1");
is($services->objURI->[1], 'urn:ietf:params:xml:ns:epp:contact-1.0', "Correct objURI 2");

done_testing();
