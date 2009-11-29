
package PRANG::Graph::Context;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;

# this is a data class, it basically is like a loop counter for
# parsing.  Except instead of walking over a list, it 'walks' over a
# tree of a certain, bound shape.

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
	isa => "Bool",
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
	isa => 'PRANG::Graph::Marshaller',
	;

has 'xpath' =>
	is => "ro",
	isa => "Str",
	;

has 'xsi' =>
	is => "ro",
	isa => "HashRef",
	;

# this one is to know if the prefix was different to the parent type.
has 'prefix' =>
	is => "ro",
	isa => "Str",
	;

BEGIN { class_type "XML::LibXML::Node" };

# this is a very convenient class to put a rich and useful exception
# method on; all important methods use it, and it has just the
# information to make the error message very useful.
method exception( Str $message, XML::LibXML::Node $node? ) {
	my $extra = "";
	if ( $node and $node->isa("XML::LibXML::Element") ) {
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
	elsif ( $node and $node->isa("XML::LibXML::Text") ) {
		my $val = $node->value;
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
	die "$message at ".$self->xpath."$extra";
}

1;
