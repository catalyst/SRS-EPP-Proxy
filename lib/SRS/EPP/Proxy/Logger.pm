
package SRS::EPP::Proxy::Logger;

use Moose::Role;

our $min_level = "info";
(our $ident = $0) =~ s{.*/}{};
our $logopt = "pid";
our $facility = "daemon";
our $use_syslog;

# convenience wrapper for Log::Dispatch; makes the 'log' method
# available.
has 'log' =>
	is => "ro",
	isa => "Log::Dispatch",
	lazy => 1,
	default => sub {
		our $dispatcher;
		return $dispatcher if $dispatcher;
		$dispatcher = Log::Dispatch->new;
		if ( !defined $use_syslog ) {
			$use_syslog = ! -t STDERR;
		}
		if ( $use_syslog ) {
			$dispatcher->add(
				Log::Dispatch::Syslog->new(
					name => "syslog",
					min_level => $min_level,
					ident => $ident,
					logopt => $logopt,
					facility => $facility,
				       ),
			       );
		}
		else {
			$dispatcher->add(
				Log::Dispatch::Screen->new(
					name => "screen",
					min_level => $min_level,
					stderr => 1,
				       ),
			       );
		}
		$dispatcher;
	};

1;
