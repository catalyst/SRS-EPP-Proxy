
package PRANG::Graph::Text;

use Moose;
use MooseX::Method::Signatures;
with 'PRANG::Graph::Node';

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	if ( $node->nodeType == XML_TEXT_NODE ) {
		(undef, $node->value);
	}
	elsif ( $node->nodeType == XML_CDATA_SECTION_NODE ) {
		(undef, $node->value);
	}
	else {
		$ctx->exception("expected text node");
	}
}

method complete( PRANG::Graph::Context $ctx ) {
	# ...
}

method expected( PRANG::Graph::Context $ctx ) {
	#...
}

1;
