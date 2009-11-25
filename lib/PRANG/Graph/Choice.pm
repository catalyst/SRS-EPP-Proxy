
package PRANG::Graph::Choice;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'choices' =>
	is => "ro",
	isa => "ArrayRef[PRANG::Graph::Node]",
	default => sub { [] },
	;

method textnode_ok( Int $pos ) {
	if ( $pos > 1 ) {
		return 0;
	}
	for my $choice ( @{ $self->choices } ) {
		return 1 if $choice->textnode_ok(1);
	}
	return 0;
}

method element_ok( Str $xmlns?, Str $nodename, Int $pos ) {
	if ( $pos > 1 ) {
		return 0;
	}
	for my $choice ( @{ $self->choices } ) {
		if ($choice->element_ok($xmlns, $nodename, $pos)) {
			return 1;
		}
	}
	return 0;
}

method element_class( Str $xmlns?, Str $nodename, Int $pos ) {
	my @classes;
	for my $choice ( @{ self->choices} ) {
		if ( $choice->element_ok($xmlns, $nodename, $pos) ) {
			push @classes, $choice->element_class(
				$xmlns, $nodename, $pos
			       );
		}
	}
	die "non-definite acceptor in graph" if @classes != 1;
	return $classes[0];
}

1;
