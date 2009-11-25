
package PRANG::Graph::Quantity;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'min' =>
	is => "ro",
	isa => "Int",
	predicate => "has_min",
	;

has 'max' =>
	is => "ro",
	isa => "Int",
	predicate => "has_max",
	;

has 'child' =>
	is => "ro",
	isa => "PRANG::Graph::Node",
	;

method textnode_ok( Int $pos ) {
	if ( $self->has_max and $pos > $self->max ) {
		return 0;
	}
	return $self->child->textnode_ok;
}

method element_ok( Str $xmlns?, Str $nodename, Int $pos ) {
	if ( $self->has_max and $pos > $self->max ) {
		return 0;
	}
	return $self->child->element_ok($xmlns, $nodename, 1);
}

method pop_ok( Int $pos ) {
	if ( $self->has_min and $pos < $self->min ) {
		return 0;
	}
	1;
}

method element_class( Str $xmlns?, Str $nodename, Int $pos ) {
	return $self->child->element_class($xmlns, $nodename, 1);
}

1;
