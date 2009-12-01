
package PRANG::Graph::Text;

use Moose;
use MooseX::Method::Signatures;
use XML::LibXML;

has 'attrName' =>
	is => "ro",
	isa => "Str",
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	if ( $node->nodeType == XML_TEXT_NODE ) {
		($self->attrName, $node->data);
	}
	elsif ( $node->nodeType == XML_CDATA_SECTION_NODE ) {
		($self->attrName, $node->data);
	}
	else {
		$ctx->exception("expected text node", $node);
	}
}

method complete( PRANG::Graph::Context $ctx ) {
	1;
}

method expected( PRANG::Graph::Context $ctx ) {
	"TextNode";
}

method output {
}

with 'PRANG::Graph::Node';

1;
