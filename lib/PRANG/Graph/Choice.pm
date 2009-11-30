
package PRANG::Graph::Choice;

use Moose;
use MooseX::Method::Signatures;

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

method output ( Object $item, XML::LibXML::Element $node, HashRef $xsi ) {
	# FIXME - need the meta-attribute, dammit!
}

with 'PRANG::Graph::Node';

1;
