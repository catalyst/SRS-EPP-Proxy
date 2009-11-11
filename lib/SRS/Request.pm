
package SRS::Request;

use Moose;
use Moose::Util::TypeConstraints;

subtype 'SRS::ActionID'
	=> as "Str",
	;

has 'action_id' =>
	is => "rw",
	isa => "SRS::ActionID",
	;

extends 'SRS::EPP::Message';

1;
