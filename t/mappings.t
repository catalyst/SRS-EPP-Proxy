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

    ## ---
    # Step 1 - convert the EPP message into an SRS one

    # create the EPP XML from the template plus vars
    my $epp_xml_str;
    my $ret = $tt->process( 'frame.tt', $yaml->{vars}, \$epp_xml_str );

    # test this XML against our initial assertions
    XMLMappingTests::run_testset( $epp_xml_str, $yaml->{initial_epp_assertions} );

    print 'EPP request  = ', $epp_xml_str if $VERBOSE;

    # parse the XML to get an XML::EPP object
    my $xml_epp = XML::EPP->parse( $epp_xml_str );

    # check that this is an XML::EPP object
    ok( ref $xml_epp eq 'XML::EPP', 'Check the templated in XML was parsed ok' );

    # check the round-tripping (same tests as earlier)
    XMLMappingTests::run_testset( $xml_epp->to_xml(), $yaml->{initial_epp_assertions} );

    # create a queue item
    my $queue_item = SRS::EPP::Command->new(
        message => $xml_epp,
        session => $session,
    );

    # now get the SRS XML
    my @srs_xml = $queue_item->to_srs();

    # make a new transaction, which puts these messages into an NZSRSRequest
	my $tx = XML::SRS::Request->new(
		version => "auto",
		requests => [ @srs_xml ],
		);

    print 'SRS request  = ', $tx->to_xml(), "\n" if $VERBOSE;

    # now test the assertions
    XMLMappingTests::run_testset( $tx->to_xml(), $yaml->{srs_assertions} );

    ## ---
    # Step 2 - Convert the SRS message back into EPP

    if ( $yaml->{example_srs_response} ) {
        # assume we have the XML ... from the YAML file
        my $srs_xml_str = $yaml->{example_srs_response};
        print "SRS response = $srs_xml_str\n" if $VERBOSE;

        # parse the message and put it in a transaction
        my $message = XML::SRS::Response->parse($srs_xml_str);
        my $rs_tx = SRS::EPP::SRSMessage->new( message => $message );

        # these 'parts' are SRS::EPP::SRSResponse, which notify() needs an array of
        my @parts = @{$rs_tx->parts()};
        $queue_item->notify( @parts );

        # now create the EPP response
        my $resp = $queue_item->response();

        # print out the XML
        print 'EPP response = ', $resp->to_xml() if $VERBOSE;

        # finally, after years of trying, test the EPP returned message
        XMLMappingTests::run_testset( $resp->to_xml(), $yaml->{epp_assertions} );
    }
    else {
        diag("Warning: No example srs response to be unit tested");
    }

    ## ---
    # Step 3 - do some integrated tests

    # ToDo
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
