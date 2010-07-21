# Run the mappings tests as fully integrated tests, i.e. use brause to send requests to an SRS EPP Proxy, and on to
#  an SRS.
# Only runs if appropriate environment vars are set, i.e. not usually run as part of 'make test', unless you have
#  brause installed, a proxy configured and running, and the environment vars setup to point to it.
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use YAML qw(LoadFile);
use lib $Bin;
use XMLMappingTests;
use Data::Dumper;
use Scriptalicious;

unless ($ENV{SRS_PROXY_HOST}) {
    plan 'skip_all';    
    exit 0;   
}

my %conf = (
    host => $ENV{SRS_PROXY_HOST},
    port => 700,
    template_path => $Bin . '/templates', 
    debug => $VERBOSE ? 1 : 0,
    ssl_key => $Bin . '/auth/host.key',
    #ssl_cert => $Bin . '/auth/host.crt',
);

my @files = map { s|^t/||; $_ } @ARGV;

our @testfiles = @files ? @files : XMLMappingTests::find_tests('mappings');

foreach my $testfile (sort @testfiles) {
    my $data = XMLMappingTests::read_yaml($testfile);
    
    diag("Processing: " . $testfile);
    
    if ($data->{integration_skip}) {
        SKIP: {
            skip "Skipping in integration mode", 1;   
        }
        next;
    }

    my $vars = $data->{vars};
    $vars->{command} = $data->{template};
    $vars->{command} =~ s/\.tt$//;
    $vars->{transaction_id} = time;
    
    my $login = {
        command => 'login',
        user => '100',
        pass => 'foobar',   
    };
    
    my $test = {
        step => [
            $data->{no_auto_login} ? () : $login,
            $vars,
            {
                command => 'logout',  
            },
            
        ],
    };
    
    require Brause;
    my $res = eval { Brause::talk($test, \%conf) };
    if ($@) {
        fail("Couldn't talk to Epp proxy: $@");   
    }
    
    my $response = $res->{response}[$data->{no_auto_login} ? 0 : 1];
    
    fail("No response received") unless $response;
    
    XMLMappingTests::check_xml_assertions( $response, $data->{output_assertions}, $testfile );
}

done_testing();
