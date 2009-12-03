
package PRANG::Graph::Context;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

BEGIN {
	class_type "XML::LibXML::Element";
}

# this is a data class, it basically is like a loop counter for
# parsing (or emitting).  Except instead of walking over a list, it
# 'walks' over a tree of a certain, bound shape.

# The shape of the XML Graph at each node is limited to:
#
#  Seq -> Quant -> Choice -> Element -> ( Text | Null )
#
#  (any of the above may be absent)
#
# These variables allow us to remember where we were.
has 'seq_pos' =>
	is => "rw",
	isa => "Int",
	lazy => 1,
	default => 1,
	trigger => sub {
		my $self = shift;
		$self->clear_quant;
		$self->clear_chosen;
		$self->clear_element_ok;
	},
	;

has 'quant_found' =>
	is => "rw",
	isa => "Int",
	lazy => 1,
	default => 0,
	clearer => 'clear_quant',
	trigger => sub {
		my $self = shift;
		$self->clear_chosen;
		$self->clear_element_ok;
	},
	;

has 'chosen' =>
	is => "rw",
	isa => "Int",
	clearer => "clear_chosen",
	trigger => sub {
		$_[0]->clear_element_ok;
	}
	;

has 'element_ok' =>
	is => "rw",
	isa => "Bool",
	clearer => "clear_element_ok",
	;

# For recursion, we need to know a couple of extra things.
has 'base' =>
	is => "ro",
	isa => 'PRANG::Marshaller',
	;

has 'xpath' =>
	is => "ro",
	isa => "Str",
	;

has 'xsi' =>
	is => "rw",
	isa => "HashRef",
	default => sub { {} },
	;

has 'rxsi' =>
	is => "rw",
	isa => "HashRef",
	lazy => 1,
	default => sub {
		my $self = shift;
		{ reverse %{ $self->xsi } };
	},
	;

has 'xsi_virgin' =>
	is => "rw",
	isa => "Bool",
	default => 1,
	;

# this one is to know if the prefix was different to the parent type.
has 'prefix' =>
	is => "ro",
	isa => "Str",
	;

BEGIN { class_type "XML::LibXML::Node" };

method get_prefix( Str $xmlns, Object $thing?, XML::LibXML::Element $victim? ) {
	if ( my $prefix = $self->rxsi->{$xmlns} ) {
		$prefix;
	}
	elsif ( $thing and $thing->can("preferred_prefix") ) {
		$thing->preferred_prefix($xmlns);
	}
	elsif ( $thing and $thing->can("xmlns_prefix") ) {
		$thing->xmlns_prefix($xmlns);
	}
	else {
		my $new_prefix = $self->base->generate_prefix($xmlns);
		$self->add_xmlns($new_prefix, $xmlns);
		if ( $victim ) {
			$victim->setAttribute(
				"xmlns:".$new_prefix,
				$xmlns,
			       );
		}
		$new_prefix;
	}
}

method add_xmlns( Str $prefix, Str $xmlns ) {
	if ( $self->xsi_virgin ) {
		$self->xsi({ %{$self->xsi}, $prefix => $xmlns });
		if ( $self->rxsi ) {
			$self->rxsi({ %{$self->rxsi}, $xmlns => $prefix });
		}
	}
}

method get_xmlns( Str $prefix ) {
	$self->xsi->{$prefix};
}

# this is a very convenient class to put a rich and useful exception
# method on; all important methods use it, and it has just the
# information to make the error message very useful.
method exception( Str $message, XML::LibXML::Node $node?, Bool $skip_ok? ) {
	my $error = PRANG::Graph::Context::Error->new(
		($node ? (node => $node) : ()),
		message => $message,
		xpath => $self->xpath,
		($skip_ok ? (skip_ok => 1) : ()),
	       );
	die $error;
}

package PRANG::Graph::Context::Error;

use Moose;
use MooseX::Method::Signatures;

has 'node' =>
	is => "ro",
	isa => "XML::LibXML::Node",
	predicate => "has_node",
	;

has 'message' =>
	is => "ro",
	isa => "Str",
	;

has 'xpath' =>
	is => "ro",
	isa => "Str",
	;

has 'skip_ok' =>
	is => "ro",
	isa => "Bool",
	;

method show_node {
	return "" unless $self->has_node;
	my $extra = "";
	my $node = $self->node;
	if ( $node->isa("XML::LibXML::Element") ) {
		$extra = " (parsing: <".$node->nodeName;
		if ( $node->hasAttributes ) {
			$extra .= join(" ", map {
				$_->name."='".$_->value."'"
			} $node->attributes);
		}
		if ( $node->hasChildNodes ) {
			my @nodes = grep { !$_->isa("XML::LibXML::Comment") }
				$node->nonBlankChildNodes;
			if ( @nodes > 1 and
				     grep { !$_->isa("XML::LibXML::Element") }
					     @nodes ) {
				$extra .= ">(mixed context)";
			}
			elsif ($nodes[0]->isa("XML::LibXML::Element")) {
				$extra .= "><!-- ".@nodes
					." child XML nodes -->";
			}
			else {
				$extra .= ">(text content)";
			}
			$extra .= "</".$node->nodeName.">";
		}
		else {
			$extra .= " />";
		}
		$extra .= ")";
	}
	elsif ( $node->isa("XML::LibXML::Text") ) {
		my $val = $node->data;
		if ( length($val) > 15 ) {
			$val = substr($val, 0, 13);
			$val .= "...";
		}
		$extra .= " (at text node: '$val')";
	}
	elsif ( $node ) {
		my $type = ref $node;
		$type =~ s{XML::LibXML::}{};
		$extra .= " (bogon? $type node)";
	}
	$extra;
}

sub build_error {
	my $self = shift;
	my $message = $self->message;
	my $extra = $self->show_node;
	return "$message at ".$self->xpath."$extra\n";
}

use overload '""' => \&build_error;

1;
