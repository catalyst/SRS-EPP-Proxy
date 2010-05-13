
use Getopt::Long;

use Log::Log4perl qw(:easy);
my $log_level = $ERROR;
GetOptions(
	"verbose|v" => sub { $log_level = $INFO },
	"debug|d" => sub { $log_level = $DEBUG },
	"trace|t" => sub { $log_level = $TRACE },
       );

Log::Log4perl->easy_init($log_level);

1;
