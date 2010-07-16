
package XMLMappingTests;

BEGIN { *$_ = \&{"main::$_"} for qw(ok diag) }

use Scriptalicious;
use File::Find;
use FindBin qw($Bin $Script);
use strict;
use YAML qw(LoadFile Load Dump);
use XML::LibXML;
use Test::XML::Assert;
use Test::More;

our $grep;
getopt_lenient( "test-grep|t=s" => \$grep );

# get an XML parser
my $parser = XML::LibXML->new();
my $xmlns = {
    epp => 'urn:ietf:params:xml:ns:epp-1.0',
    domain => 'urn:ietf:params:xml:ns:domain-1.0',
    host => 'urn:ietf:params:xml:ns:host-1.0',
    contact => 'urn:ietf:params:xml:ns:contact-1.0',
};

sub find_tests {
	my $group = shift || ($Script=~/(.*)\.t$/)[0];

	my @tests;
	find(sub {
		     if ( m{\.(?:x|ya)ml$} && (!$grep||m{$grep}) ) {
			     my $name = $File::Find::name;
			     $name =~ s{^\Q$Bin\E/}{} or die;
			     push @tests, $name;
		     }
	     }, "$Bin/$group");
	@tests;
}

sub read_xml {
	my $test = shift;
	
	open XML, "<$Bin/$test";
	binmode XML, ":utf8";
	my $xml = do {
		local($/);
		<XML>;
	};
	close XML;
	$xml;
}

sub read_yaml {
	my $test = shift;

	my $file = $test =~ m|^/| ? $test : "$Bin/$test"; 

	LoadFile $file;
}

sub run_testset {
    my ($xml, $testset) = @_;

    # firstly, make an XML document with the input $xml
    my $doc = $parser->parse_string( $xml )->documentElement();
    
    my $failure = 0;

    # then check that we actually have something to test (this should always be
    # defined)
    ok(ref $testset eq 'HASH', 'Check that this testset actually has been passed something');

    # if we have some count tests, run those first
    if ( defined $testset->{count} ) {
        for my $t ( @{$testset->{count}} ) {
            # print Dumper($t);
            # print "Doing test $t->[2]\n";
            $failure ||= ! is_xpath_count( $doc, $xmlns, $t->[0], $t->[1], $t->[2] );
            # print "Done\n";
        }
    }

    # if we have some matches
    if ( defined $testset->{match} ) {
        for my $t ( @{$testset->{match}} ) {
            $failure ||= ! does_xpath_value_match( $doc, $xmlns, $t->[0], $t->[1], $t->[2] );
        }
    }

    # if we have some match_all
    if ( defined $testset->{match_all} ) {
        for my $t ( @{$testset->{match_all}} ) {
            $failure ||= ! do_xpath_values_match( $doc, $xmlns, $t->[0], $t->[1], $t->[2] );
        }
    }

    # if we some attribute checks
    if ( defined $testset->{attr_is} ) {
        for my $t ( @{$testset->{attr_is}} ) {
            $failure ||= ! does_attr_value_match( $doc, $xmlns, $t->[0], $t->[1], $t->[2], $t->[3] );
        }
    }
    
    if ($failure) {
        diag "Epp response: $xml";   
    }
}

1;
