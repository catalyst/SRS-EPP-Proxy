
package SRS::EPP::SRSResponse;

use Moose;

extends 'SRS::EPP::Message';

use XML::SRS;
has "+message" =>
	isa => "XML::SRS::Result|XML::SRS::Error",
	handles => [qw(action_id)],
	;

1;
