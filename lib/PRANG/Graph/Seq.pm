
package PRANG::Graph::Seq;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

has 'members' =>
	is => "ro",
	isa => "ArrayRef[PRANG::Graph::Node]",
	default => sub { [] },
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	my $pos = $ctx->seq_pos;
	my ($key, $val, $x);
	do {
		my $member = $self->members->[$pos-1]
			or $ctx->exception("unexpected element", $node);
		($key, $val, $x) = $member->accept($node, $ctx);
		$pos++;
	} until ($key);
	$ctx->seq_pos($pos);
	($key, $val, $x);
}

method complete( PRANG::Graph::Context $ctx ) {
	return ( $ctx->seq_pos-1 == @{$self->members});
}

method expected( PRANG::Graph::Context $ctx ) {
	#...
}

1;
