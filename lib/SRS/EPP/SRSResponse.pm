
package SRS::EPP::SRSResponse;

use Moose;

extends 'SRS::EPP::Message';

use XML::SRS;
has "+message" =>
	isa => "XML::SRS::Result",
	handles => [qw(action_id)],
	;

1;
