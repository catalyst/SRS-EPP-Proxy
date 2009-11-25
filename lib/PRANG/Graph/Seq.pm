
package PRANG::Graph::Seq;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'members' =>
	is => "ro",
	isa => "ArrayRef[PRANG::Graph::Node]",
	default => sub { [] },
	;

method textnode_ok( Int $pos ) {
	my $member = $self->members->[$pos-1];
	return ( $member and $member->textnode_ok(1) );
}

method element_ok( Str $xmlns?, Str $nodename, Int $pos ) {
	my $member = $self->members->[$pos-1];
	return ( $member and $member->element_ok($xmlns, $nodename, 1) );
}

method pop_ok( Int $pos ) {
	return ( $pos == scalar(@{ $self->members }) );
}

method element_class( Str $xmlns?, Str $nodename, Int $pos ) {
	my $member = $self->members->[$pos-1];
	return ( $member->element_class($xmlns, $nodename, 1) );
}

1;
