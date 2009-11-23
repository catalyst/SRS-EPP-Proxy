
package SRS::Request;

use Moose::Role;
use Moose::Util::TypeConstraints;

with 'SRS::EPP::Message';

subtype 'SRS::ActionID'
	=> as "Str",
	;

has 'action_id' =>
	is => "rw",
	isa => "SRS::ActionID",
	;

1;
