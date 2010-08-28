
use Log::Log4perl qw(:easy);

my $log_level = $ERROR;

use Scriptalicious;

getopt_lenient();

$log_level = (
	$main::VERBOSE > 2 ? $TRACE :
		$main::VERBOSE > 1 ? $DEBUG :
		$main::VERBOSE > 0 ? $INFO : $FATAL
);

Log::Log4perl->easy_init($log_level);

1;
