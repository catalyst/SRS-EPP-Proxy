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
    INCLUDE_PATH => 't/templates/',
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

    print 'EPP request  = ', $epp_xml_str if $VERBOSE;

    # test this XML against our initial assertions
    XMLMappingTests::run_testset( $epp_xml_str, $yaml->{input_assertions} );

    # parse the XML to get an XML::EPP object
    my $xml_epp = XML::EPP->parse( $epp_xml_str );

    # check that this is an XML::EPP object
    ok( ref $xml_epp eq 'XML::EPP', 'Check the templated in XML was parsed ok' );

    # check the round-tripping (same tests as earlier)
    XMLMappingTests::run_testset( $xml_epp->to_xml(), $yaml->{input_assertions} );

    # create a queue item
    my $queue_item = SRS::EPP::Command->new(
        message => $xml_epp,
        session => $session,
    );

    if ( my $class = $yaml->{input_assertions}->{class} ) {
      # Make sure that the queue_item is the right class
      my $oClass = ref($queue_item);
      ok( $oClass eq $class, "EPP: Correct object class ($oClass / $class)" );
    }

    # now get the XML generated by the proxy (could be either SRS or EPP)
    my @messages = $queue_item->process( $session );

    for my $srs_loop ( @{$yaml->{SRS}} ) {
      # Assert against last output from proxy (@messages)
      my $srs_assertions = $srs_loop->{assertions};
      my $tx = XML::SRS::Request->new(
          version => "auto",
          requests => [ @messages ],
          );
      my $xmlstring = $tx->to_xml();
      XMLMappingTests::run_testset( $xmlstring, $srs_assertions );

      # If the output from the proxy was SRS XML, we need to pretend to hit the SRS
      if ( $messages[0]->does('XML::SRS::Action') or $messages[0]->does('XML::SRS::Query') ) {
        if ( my $fake_response = $srs_loop->{fake_response} ) {
          my $message = XML::SRS::Response->parse($srs_loop->{fake_response});
          my $rs_tx = SRS::EPP::SRSMessage->new( message => $message );

          # these 'parts' are SRS::EPP::SRSResponse, which notify() needs an array of
          @messages = $queue_item->notify( @{$rs_tx->parts()} );
        }
      }
    }

    ok( $messages[0]->isa('SRS::EPP::Response'), 'test definition sane' );
    if ( $messages[0]->isa('SRS::EPP::Response') ) {
        # ToDo: we'll have to do something if there are multiple msgs returned
        my $resp = $messages[0];
        my $xml = $resp->to_xml();

        # print out the XML
        print "EPP response = $xml\n" if $VERBOSE;

        # run the output_assertions tests
        XMLMappingTests::run_testset( $xml, $yaml->{output_assertions} );
    }

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
