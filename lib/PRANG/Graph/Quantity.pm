
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
