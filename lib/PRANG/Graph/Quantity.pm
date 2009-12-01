
package PRANG::Graph::Quantity;

use Moose;
use MooseX::Method::Signatures;

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

sub accept_many { 1 }

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	my $found = $ctx->quant_found;
	my ($key, $value, $x) = eval { $self->child->accept($node, $ctx) };
	if ( !$key ) {
		my $X = $@;
		my $skip_ok = not $X;
		# XXX - exceptions are not flow control.
		$skip_ok ||= (ref $X and $X->has_node and
				      $X->node == $node and $X->skip_ok);
		if ( $skip_ok and $self->complete($ctx) ) {
			return();
		}
		else {
			die $X;
		}
	}
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

method expected( PRANG::Graph::Context $ctx ) {
	my $desc;
	if ( $self->has_min ) {
		if ( $self->has_max ) {
			$desc = "between ".$self->min." and ".$self->max;
		}
		else {
			$desc = "at least ".$self->min;
		}
	}
	else {
		if ( $self->has_max ) {
			$desc = "optionally up to ".$self->max;
		}
		else {
			$desc = "zero or more";
		}
	}
	my @expected = $self->child->expected($ctx);
	return("($desc of: ", @expected, ")");
}

method output {}

with 'PRANG::Graph::Node';

1;
