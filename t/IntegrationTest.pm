package IntegrationTest;

# Run the mappings tests as fully integrated tests, i.e. use brause to send requests to an SRS EPP Proxy, and on to
#  an SRS.
# Only runs if appropriate environment vars are set, i.e. not usually run as part of 'make test', unless you have
#  brause installed, a proxy configured and running, and the environment vars setup to point to it.
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use YAML qw(LoadFile);
use XMLMappingTests;
use Data::Dumper;
use Scriptalicious;
use File::Basename;

sub run_tests {
    my @files = @_;
    
    my $stash = {};
    if (ref $files[0] eq 'HASH') {
        $stash = shift @files;   
    }
    
    unless ($ENV{SRS_PROXY_HOST}) {
        plan 'skip_all';    
        exit 0;   
    }
    
    my $test_dir = "$Bin/../../../submodules/SRS-EPP-Proxy/t/";
    
    my %conf = (
        host => $ENV{SRS_PROXY_HOST},
        port => 700,
        template_path => $test_dir . 'templates', 
        debug => $VERBOSE ? 1 : 0,
        ssl_key => $test_dir . '/auth/client-key.pem',
        ssl_cert => $test_dir . '/auth/client-cert.pem',
    );
    
    @files = map { s|^t/||; $_ } @files;
    
    my @testfiles = @files ? @files : XMLMappingTests::find_tests('mappings');
    
    foreach my $testfile (sort @testfiles) {
        my $data = XMLMappingTests::read_yaml($testfile);
        
        diag("Processing: " . $testfile);
        
        if ($data->{integration_skip}) {
            SKIP: {
                skip "Skipping in integration mode", 1;   
            }
            next;
        }
        
        my $vars = { %{$data->{vars} || {}}, ($data->{int_dont_use_stash} ? () : %$stash) };
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
        
        if ($response) {                
            XMLMappingTests::check_xml_assertions( $response, $data->{output_assertions}, basename $testfile );
        }
        else {
            fail("No response received") 
        }        
    }
    
    done_testing();
}

1;