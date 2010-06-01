#!/usr/bin/perl

# Test script for checking the mappings of the XML Mappings to/from SRS <-> EPP
# messages.

#
# See:
# RFC5730 - EPP
# RFC5731 - Domain Name Mapping
# RFC5732 - Host Mapping
# RFC5733 - Contact Mapping

use strict;
use warnings;

use Data::Dumper;
use YAML;
use Scriptalicious;
use XML::EPP;
use XML::EPP::Domain;
use XML::EPP::Host;
use XML::EPP::Contact;
use SRS::EPP::Command;
use Test::XML::Assert;
use Test::More qw(no_plan);
use Template;
use FindBin qw($Bin);
use lib $Bin;
use Mock;
use XMLMappingTests;

our @testfiles = XMLMappingTests::find_tests;

# get an XML parser
my $parser = XML::LibXML->new();

# get a template object
my $tt = Template->new({
    # FIXME: this shouldn't be relative
    INCLUDE_PATH => '../brause/share/Brause/NZRS/',
});

# create an SRS::EPP::Session
my $session = SRS::EPP::Session->new(
    event => undef,
    proxy => Mock::Proxy->new(),
    backend_url => '',
);

for my $testfile ( sort @testfiles ) {
    diag("Reading $testfile");
    my $yaml = XMLMappingTests::read_yaml($testfile);

    # this 'command' is wrapped by frame.tt
    $yaml->{vars}{command} = $yaml->{template};

    # Order of things to do:
    # 1) a session object already exists
    # 2) create the XML from the templated file and $yaml->{vars}
    # 3) test that XML against our initial assertions
    # 4) parse the XML to get an XML::EPP object
    # 5) test the XML::EPP->to_xml() against our same initial assertions
    # 6) create a queue item, passing it the XML
    # 7) FIXME: rebless
    # 8) create the SRS xml messages
    # 9) make a transaction (which wraps the messages in an NZSRSRequest)
    # 10) test that against what we expect has been created

    # make the EPP (templated) XML and sanity check it
    my $epp_xml_str;
    my $ret = $tt->process( 'frame.tt', $yaml->{vars}, \$epp_xml_str );
    XMLMappingTests::run_testset( $epp_xml_str, $yaml->{initial_epp_assertions} );

    # parse the XML to get an XML::EPP object
    my $xml_epp = XML::EPP->parse( $epp_xml_str );

    # check that this is an XML::EPP object
    ok( ref $xml_epp eq 'XML::EPP', 'Check the templated in XML was parsed ok' );

    # and check the round-tripping passes our expectations
    XMLMappingTests::run_testset( $xml_epp->to_xml(), $yaml->{initial_epp_assertions} );

    # create a queue item
    my $queue_item = SRS::EPP::Command::Check::Domain->new(
        message => $xml_epp,
        xml     => $epp_xml_str,
        session => $session,
    );

    # FIXME: rebless $queue_item into the proper one and see if it works
    bless $queue_item, 'SRS::EPP::Command::Check::Domain';

    # now get the SRS XML
    my @srs_xml = $queue_item->to_srs( $session );

    # make a new transaction, which puts these messages into an NZSRSRequest
	my $tx = XML::SRS::Request->new(
		version => "auto",
		requests => [ @srs_xml ],
		);

    # now test the assertions
    XMLMappingTests::run_testset( $tx->to_xml(), $yaml->{srs_assertions} );

    # ToDo: reverse conversion tests ($srs -> $epp)
    # ToDo: integration tests

}

# Copyright (C) 2010  NZ Registry Services
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
