
package PRANG::Graph::Element;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

BEGIN {
	class_type "XML::LibXML::Node";
	class_type "XML::LibXML::Element";
}

has 'xmlns' =>
	is => "ro",
	isa => "Str",
	predicate => "has_xmlns",
	;

has 'nodeName' =>
	is => "ro",
	isa => "Str",
	required => 1,
	;

has 'nodeClass' =>
	is => "ro",
	isa => "Str",
	predicate => "has_nodeClass",
	;

has 'attrName' =>
	is => "ro",
	isa => "Str",
	required => 1,
	;

has 'contents' =>
	is => "rw",
	isa => "PRANG::Graph::Node",
	predicate => "has_contents",
	;

method accept( XML::LibXML::Node $node, PRANG::Graph::Context $ctx ) {
	if ( ($node->prefix||"") ne ($ctx->prefix||"") ) {
		my $got_xmlns = ($ctx->xsi->{$node->prefix}||"");
		my $wanted_xmlns = ($self->xmlns||"");
		if ( $wanted_xmlns ne "*" and
			     $got_xmlns ne $wanted_xmlns ) {
			$ctx->exception("invalid XML namespace", 1);
		}
	}
	# this is bad for processContents=skip + namespace="##other"
	my $ret_nodeName = $self->nodeName eq "*" ?
		$node->localname : undef;
	if ( !$ret_nodeName and $node->localname ne $self->nodeName ) {
		$ctx->exception(
		"invalid element; expected '".$self->nodeName."'",
			$node, 1,
		       );
	}
	if ( $self->has_nodeClass ) {
		# general nested XML support
		my $marshaller = $ctx->base->get($self->nodeClass);
		my $value = $marshaller->marshall_in_element(
			$node,
			$ctx->xsi,
			$ctx->xpath."/".$node->nodeName,
		       );
		$ctx->element_ok(1);
		return ($self->attrName => $value, $ret_nodeName);
	}
	else {
		# XML data types
		if ($node->hasAttributes) {
			$ctx->exception(
			"superfluous attributes on XML data node",
				$node);
		}
		if ( $self->has_contents ) {
			# simple types, eg Int, Str
			my (@childNodes) = $node->nonBlankChildNodes;
			if ( @childNodes > 1 ) {
				# we could maybe merge CDATA nodes...
				$ctx->exception(
			"Too many child nodes for XML data node",
					$node,
				       );
			}
			my $value;
			if ( !@childNodes ) {
				$value = "";
			} else {
				(undef, $value) = $self->contents->accept(
					$childNodes[0],
					$ctx,
				       );
			}
			$ctx->element_ok(1);
			return ($self->attrName => $value, $ret_nodeName);
		}
		else {
			# boolean
			if ( $node->hasChildNodes ) {
				$ctx->exception(
		"Superfluous child nodes on presence-only node",
					$node,
	       				);
			}
			$ctx->element_ok(1);
			return ($self->attrName => 1, $ret_nodeName);
		}
	}
}

method complete( PRANG::Graph::Context $ctx ) {
	$ctx->element_ok;
}

method expected( PRANG::Graph::Context $ctx ) {
	my $xsi = $ctx->xsi;
	my $prefix = "";
	my $nodename = $self->nodeName;
	if ( $self->has_xmlns ) {
		my $xmlns = $self->xmlns;
		if ( $prefix = $xsi->{$xmlns} ) {
			$prefix .= ":";
		}
		else {
			$prefix = $xsi->{"()"}->($xmlns);
			$nodename .= " xmlns:$prefix='$xmlns'";
			$prefix .= ":";
		}
	}
	return "<$prefix$nodename".($self->has_nodeClass?"...":
					    $self->has_contents?"":"/")
		.">";
}

method output ( Object $item, XML::LibXML::Element $node, HashRef $xsi ) {
	no strict 'refs';
	&{"..."}();
}

with 'PRANG::Graph::Node';

1;
