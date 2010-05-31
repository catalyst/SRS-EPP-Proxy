
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

sub parse_test {
	my $class = shift;
	my $xml = shift;
	my $test_name = shift;
	my $object = eval { $class->parse( $xml ) };
	my $ok = ok($object, "$test_name - parsed OK");
	if ( !$ok ) {
		diag("exception: $@");
	}
	if ( $ok and ($main::VERBOSE//0)>0) {
		diag("read: ".Dump($object));
	}
	$object;
}

sub parsefail_test {
	my $class = shift;
	my $xml = shift;
	my $test_name = shift;
	my $object = eval { $class->parse( $xml ) };
	my $error = $@;
	my $ok = ok(!$object&&$error, "$test_name - exception raised");
	if ( !$ok ) {
		diag("parsed to: ".Dump($object));
	}
	if ( $ok and ($main::VERBOSE||0)>0) {
		diag("error: ".Dump($error));
	}
	$error;
}

sub emit_test {
	my $object = shift;
	my $test_name = shift;
	start_timer;
	my $r_xml = eval { $object->to_xml };
	my $time = show_elapsed;
	ok($r_xml, "$test_name - emitted OK ($time)")
		or do {
			diag("exception: $@");
			return undef;
		};
	if (($main::VERBOSE||0)>0) {
		diag("xml: ".$r_xml);
	}
	return $r_xml;
}

sub xml_compare_test {
	my $xml_compare = shift;
	my $r_xml = shift;
	my $xml = shift;
	my $test_name = shift;

	my $is_same = $xml_compare->is_same($r_xml, $xml);
	ok($is_same, "$test_name - XML output same")
		or diag("Error: ".$xml_compare->error);

}

1;
