
package SRS::EPP::Proxy::UA;

use base qw(LWP::Parallel::UserAgent);

sub new {
	my $class = shift;
	my $session = shift;
	my $self = $class->SUPER::new(@_);
	$self->{_session} = $session;
	$self;
}

sub on_failure {
	my ($self, $request, $response, $entry) = @_;

	print "Failed to connect to ",$request->url,"\n\t",
		$response->code, ", ", $response->message,"\n"
			if $response;

}

sub on_return {
	my ($self, $request, $response, $entry) = @_;
	if ($response->is_success) {

		# unpack it...
		my (%x) = map { m{^([^=]+)=(.*) } && ($1, urldecode($2)) }
			split "&", $response->content;

		my $rs_tx = SRS::Tx->parse( $x{r} );
		my @parts = $rs_tx->messages;
		my $session = $self->{_session};
		$session->be_response($_) for @parts;

	} else {
		print "\n\nBummer! Request to ",$request->url," returned code ", $response->code,
			": ", $response->message, "\n";
		# print $response->error_as_HTML;
	}
	return;
}

1;

__END__
