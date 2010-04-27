
package SRS::EPP::SRSRequest;

use Moose;
use Moose::Util::TypeConstraints;

extends 'SRS::EPP::Message';

use XML::SRS;
has "+message" =>
	isa => "XML::SRS::Action|XML::SRS::Query",
	handles => [ qw(action_id) ],
	;

1;
