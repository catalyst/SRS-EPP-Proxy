package SRS::EPP::Command::PayloadClass;

use Moose::Role;

sub payload_class {
    my $self = shift;
	my $root_element = shift;
    my $xmlns = shift;
	our $payload_classes;
	if ( !$payload_classes ) {
		$payload_classes = {
			map {
				$_->can("xmlns") ?
					($_->action.":".$_->xmlns => $_)
						: ();
			} $self->plugins,
		};
	}
	$payload_classes->{ $root_element.":".$xmlns };
}

sub REBLESS {
	my $self = shift;
	if ( my $epp = $self->message ) {
		my $payload = eval { $epp->message->argument->payload } or return;
		# print "payload is $payload\n";

		# ASSERT($payload->does("PRANG::Graph"));

        my $root_element = $payload->root_element;
        my $xmlns = $payload->xmlns;

        # print "looking for plugin that handles $root_element ($xmlns)\n";

        if (my $class = $self->payload_class($root_element, $xmlns)) {
            # print "reblessing $self into $class\n";
            bless $self, $class;
            no strict 'refs';
			$self->REBLESS if defined &{"${class}::REBLESS"};
        }
	}
}

1;
