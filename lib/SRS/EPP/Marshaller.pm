
package SRS::EPP::Marshaller;

# dummy marshaller...

use Moose;
use MooseX::Method::Signatures;

has 'xmlns' =>
	is => "ro",
	isa => "Str",
	required => 1,
	;

sub parse {
	my $self = shift;
	my $document = shift;
	
}
