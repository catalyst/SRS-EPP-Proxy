
package PRANG::Graph::Element;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'xmlns' =>
	is => "ro",
	isa => "Str",
	predicate => "has_xmlns",
	;

has 'nodeName' =>
	is => "ro",
	isa => "Str",
	;

has 'nodeClass' =>
	is => "ro",
	isa => "Str",
	;

method textnode_ok( Int $pos ) { 0 }
method element_ok( Str $xmlns?, Str $nodename, Int $pos ) {
	if ( $xmlns and !$self->has_xmlns ) {
		# not expected to change namespaces here!
		return 0;
	}
	elsif ( !$xmlns and $self->has_xmlns ) {
		# must change namespaces here..
		return 0
	}
	if ( $pos == 1 and $nodename eq $self->nodeName ) {
		return 1;
	}
	else {
		return 0;
	}
}

method element_class {
	return $self->nodeClass;
}

1;
