
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
