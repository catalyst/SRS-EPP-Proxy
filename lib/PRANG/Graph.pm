
package PRANG::Graph;

use Moose::Role;

use PRANG::Graph::Meta::Attribute;
use PRANG::Graph::Meta::Element;
use MooseX::Method::Signatures;

use MooseX::Attributes::Curried (
	has_attr => {
		metaclass => "PRANG::Attribute",
	},
	has_element => {
		metaclass => "PRANG::Element",
	},
	;

requires 'xmlns';
requires 'root_element';

our %marshallers;

method marshaller($inv:) returns PRANG::Marshaller {
	if ( ref $inv ) {
		$inv = ref $inv;
	}
	$marshallers{$inv} ||=
		PRANG::Marshaller->new( class => $inv->meta );
}

method parse($class: Str $xml) {
	my $instance = $class->marshaller->parse($xml);
	return $instance;
}

method to_xml() {
	$self->marshaller->to_xml($self);
}

1;

=head1 NAME

PRANG::Graph - validator and marshaller for XML

=head1 SYNOPSIS

 package My::XML::Language;
 use Moose;
 with 'PRANG::Graph';
 sub xmlns {
    "some:urn";
 }

 method root_element( Str $name ) {
     # ... do something with $name ...
 }

 package main;

 my $parsed = My::XML::Language->parse($xml);

 print $parsed->to_xml;

=head1 DESCRIPTION



=cut

