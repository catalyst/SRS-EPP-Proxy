
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
	required => 1,
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	my $found = $ctx->quant_found;
	my ($key, $value, $x) = $self->child->accept($node, $ctx);
	$found++;
	$ctx->quant_found($found);
	if ( $self->has_max and $found > $self->max ) {
		$ctx->exception("node appears too many times", $node);
	}
	($key, $value, $x);
}

method complete( PRANG::Graph::Context $ctx ) {
	my $found = $ctx->quant_found;
	return !( $self->has_min and $found < $self->min );
}

method expected {
	# ...
}

1;

__END__

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

method skip_ok( Int $pos, Int $found ) {
	if ( $self->has_min and $found < $self->min ) {
		return 0;
	}
	else {
		return 1;
	}
}

method pos_inc( Int $pos ) {
	return 0;
}

method att_what( Int $pos ) {
	return $self->child->element_class($xmlns, $nodename, 1);
}

1;
