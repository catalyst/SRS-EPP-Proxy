
package PRANG::Graph::Choice;

use Moose;
use MooseX::Method::Signatures;

has 'choices' =>
	is => "ro",
	isa => "ArrayRef[PRANG::Graph::Node]",
	default => sub { [] },
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	my $num;
	for my $choice ( @{ $self->choices } ) {
		$num++;
		my ($key, $val, $x) = eval { $choice->accept($node, $ctx) };
		if ( $key ) {
			$ctx->chosen($num);
			return ($key, $val, $x||$choice->nodeName||"");
		}
		elsif ( my $X = $@ ) {
			# XXX - exceptions are not flow control.
			if ( ref $X and $X->has_node and
				     $X->node == $node and $X->skip_ok ) {
				next;
			}
			else {
				die $X;
			}
		}
	}
	return ();
}

method complete( PRANG::Graph::Context $ctx ) {
	$ctx->chosen;
}

method expected( PRANG::Graph::Context $ctx ) {
	if ( my $num = $ctx->chosen ) {
		return $self->choices->[$num-1]->expected($ctx);
	}
	else {
		my @choices;
		for my $choice ( @{$self->choices} ) {
			push @choices, $choice->expected($ctx);
		}
		return @choices;
	}
}

method output ( Object $item, XML::LibXML::Element $node, HashRef $xsi ) {
	# FIXME - need the meta-attribute, dammit!
}

with 'PRANG::Graph::Node';

1;
