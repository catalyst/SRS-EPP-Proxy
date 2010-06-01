
package XMLMappingTests;

BEGIN { *$_ = \&{"main::$_"} for qw(ok diag) }

use Scriptalicious;
use File::Find;
use FindBin qw($Bin $Script);
use strict;
use YAML qw(LoadFile Load Dump);

our $grep;
getopt_lenient( "test-grep|t=s" => \$grep );

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
	LoadFile "$Bin/$test";
}

1;
