
package PRANG::Graph::Choice;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'choices' =>
	is => "ro",
	isa => "ArrayRef[PRANG::Graph::Node]",
	default => sub { [] },
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	for my $choice ( @{ $self->choices } ) {
		my ($key, $val, $x) = eval { $choice->accept($node, $ctx) };
		if ( $key ) {
			$ctx->chosen(1);
			return ($key, $val, $x||$choice->nodeName||"");
		}
	}
}

method complete( PRANG::Graph::Context $ctx ) {
	$ctx->chosen;
}

method expected( PRANG::Graph::Context $ctx ) {
	#...
}

1;

__END__

method textnode_ok( Int $pos, Int $found ) {
	if ( $pos > 1 ) {
		return 0;
	}
	for my $choice ( @{ $self->choices } ) {
		return 1 if $choice->textnode_ok(1);
	}
	return 0;
}

method element_ok( Str $xmlns?, Str $nodename, Int $pos, Int $found ) {
	if ( $pos > 1 ) {
		return 0;
	}
	my $found;
	for my $choice ( @{ $self->choices } ) {
		if ($choice->element_ok($xmlns, $nodename, $pos)) {
			$self->last_choice($choice);
			$found++;
		}
	}
	return !!$found;
}

method att_what( Int $pos ) {
	my ($class, $pos_inc, $next_node) =
		$self->last_choice->att_what(1);

	return ($class, 1, $next_node);
}

1;
