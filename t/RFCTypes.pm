
# This package contains classes required to get the RFC examples to
# validate.

package XML::EPP::Obj::info;

use Moose;
use PRANG::Graph;

with 'XML::EPP::Plugin';

#      <obj:info xmlns:obj="urn:ietf:params:xml:ns:obj">
#        <obj:name>example</obj:name>
#      </obj:info>
sub xmlns { "urn:ietf:params:xml:ns:obj" }
sub root_element {
	"info"
};

has_element 'name' =>
	is => "ro",
	isa => "Str",
	;

package XML::EPP::Obj::creData;

use Moose;
#      <obj:creData xmlns:obj="urn:ietf:params:xml:ns:obj">
#        <obj:name>example</obj:name>
#      </obj:creData>
extends 'XML::EPP::Obj::info';

sub root_element {
	"creData"
};

1;

