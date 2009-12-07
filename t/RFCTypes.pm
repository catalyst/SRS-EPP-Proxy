
# This package contains classes required to get the RFC examples to
# validate.

package XML::EPP::Obj::Node;
use Moose::Role;
sub xmlns { "urn:ietf:params:xml:ns:obj" }
with 'PRANG::Graph::Class';

package XML::EPP::Obj::info;

use Moose;
use PRANG::Graph;

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
	predicate => "has_name",
	;

sub is_command { 1 }
with 'XML::EPP::Plugin';

package XML::EPP::Obj::creData;

use Moose;
#      <obj:creData xmlns:obj="urn:ietf:params:xml:ns:obj">
#        <obj:name>example</obj:name>
#      </obj:creData>
extends 'XML::EPP::Obj::info';

sub root_element {
	"creData"
};

package XML::EPP::Obj::foo;
#    <ext:foo xmlns:ext="urn:ietf:params:xml:ns:ext">
#      <!-- One or more extension child elements. -->
#    </ext:foo>

use Moose;
with 'XML::EPP::Extension::Type', 'XML::EPP::Obj::Node';
sub root_element { "foo" }
sub xmlns { "urn:ietf:params:xml:ns:ext" }
sub is_command { 1 }

package XML::EPP::Obj::check;

use Moose;
use PRANG::Graph;
sub root_element { "check" }
sub xmlns { "urn:ietf:params:xml:ns:obj" }
sub is_command { 1 }

has_element "name" =>
	is => "ro",
	isa => "ArrayRef[Str]",
	;

with 'XML::EPP::Plugin', 'XML::EPP::Obj::Node';

package XML::EPP::Obj::check::RS::cd::name;
use Moose;
use PRANG::Graph;
has_attr 'avail' =>
	is => "ro",
	isa => "Bool",
	;
has_element 'content' =>
	is => "ro",
	isa => "Str",
	xml_nodeName => "",
	;
with 'XML::EPP::Obj::Node';

package XML::EPP::Obj::check::RS::cd;

use Moose;
use PRANG::Graph;

has_element 'name' =>
	is => "ro",
	isa => "XML::EPP::Obj::check::RS::cd::name",
	;
has_element 'reason' =>
	is => "ro",
	isa => "Str",
	predicate => "has_reason",
	;
with 'XML::EPP::Obj::Node';

package XML::EPP::Obj::check::RS;

use Moose;
use PRANG::Graph;
sub root_element { "chkData" }
sub is_command { 0 }

has_element "cd" =>
	is => "ro",
	isa => "ArrayRef[XML::EPP::Obj::check::RS::cd]",
	;

with 'XML::EPP::Plugin', "XML::EPP::Obj::Node";

package XML::EPP::Obj::info::RS;
# see 20-xml-rfc5730/rfc-examples/16-info-response.xml
use Moose;
use PRANG::Graph;
sub xmlns { "urn:ietf:params:xml:ns:obj" }
sub root_element {
	"infData"
};
has_element 'roid' =>
	is => "ro",
	isa => "XML::EPP::Common::roidType",
	;
sub is_command { 0 }
with 'XML::EPP::Plugin';

package XML::EPP::Obj::poll::RS;
# see 20-xml-rfc5730/rfc-examples/18-poll-response-info.xml
use Moose;
use PRANG::Graph;
sub xmlns { "urn:ietf:params:xml:ns:obj-1.0" }
has_element name => qw(is ro isa Str);
has_element trStatus => qw(is ro isa Str);
has_element reID => qw(is ro isa PRANG::XMLSchema::token);
has_element reDate => qw(is ro isa PRANG::XMLSchema::dateTime);
has_element acID => qw(is ro isa PRANG::XMLSchema::token);
has_element acDate => qw(is ro isa PRANG::XMLSchema::dateTime);
has_element exDate => qw(is ro isa PRANG::XMLSchema::dateTime);
sub root_element { "trnData" }
sub is_command { 0 }
with 'XML::EPP::Plugin';

1;

