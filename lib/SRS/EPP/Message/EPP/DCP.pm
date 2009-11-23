
package SRS::EPP::Message::EPP::DCP::Expiry;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

# hmm, choice with simpleTypes can't be mapped quite the same..
has 'absolute' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	predicate => "has_absolute",
	;

has 'relative' =>
	is => "rw",
	isa => "PRANG::XMLSchema::duration",
	predicate => "has_relative",
	;

sub BUILD {
	my $self = shift;
	if ( $self->has_absolute and $self->has_relative ) {
		die "cannot have both absolute and relative expiry";
	}
}

method attributes() {}
method elements() {
	die "tried to serialize ".__PACKAGE__." object with both "
		."absolute and relative expiry"
			if $self->has_absolute and $self->has_relative;
	( ( $self->has_absolute ? ("absolute") : ("relative") ),
	 );
}

with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::dcpExpiryType"
	=> as __PACKAGE__;

package SRS::EPP::Message::EPP::DCP::Ours;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

subtype "${SCHEMA_PKG}::dcpRecDescType"
	=> as "PRANG::XMLSchema::token"
	=> where {
		length($_) and length($_) <= 255;
	};

has 'recDesc' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRecDescType",
	predicate => "has_recDesc",
	;

method attributes() { }
method elements() {
	( ( $self->has_recDesc ? ("recDesc") : () ),
	);
}
with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::dcpOursType"
	=> as __PACKAGE__;


package SRS::EPP::Message::EPP::DCP::Recipient;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

for my $recipient ( qw(other public same unrelated) ) {
	has $recipient =>
		(is => "rw",
		 isa => "Bool",
		 predicate => "has_$recipient",
		 );
}

has 'ours' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::dcpOursType]",
	predicate => "has_ours",
	;

method attributes() { }
method elements() {
	( ( $self->has_other ? ("other") : () ),
	  ( $self->has_ours ? ("ours") : () ),
	  ( $self->has_public ? ("public") : () ),
	  ( $self->has_same ? ("same") : () ),
	  ( $self->has_unrelated ? ("unrelated") : () ),
	);
}
with 'SRS::EPP::Message::EPP::Node';

subtype "${SCHEMA_PKG}::dcpRecipientType"
	=> as __PACKAGE__;

package SRS::EPP::Message::EPP::DCP;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";

enum "${SCHEMA_PKG}::dcpAccessType"
	=> qw(all none null other personal personalAndOther);

has 'access' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpAccessType";

has 'statement' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::DCP::Statement]",
	;

has 'expiry' =>
	is => "rw",
	predicate => "has_expiry",
	isa => "${SCHEMA_PKG}::dcpExpiryType",
	;

method attributes() { }
method elements() {
	(qw(access statement),
	 ( $self->has_expiry ? ("expiry") : () ),
	);
}

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpType"
	=> as __PACKAGE__;

package SRS::EPP::Message::EPP::DCP::Statement;

use Moose;
our $SCHEMA_PKG = "SRS::EPP::Message::EPP";
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;

enum "${SCHEMA_PKG}::dcpPurposeType"
	=> qw(admin contact other prov);

has 'purpose' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpPurposeType",
	;

has 'recipient' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRecipientType",
	;

enum "${SCHEMA_PKG}::dcpRetentionType"
	=> qw(business indefinite legal none stated);

has 'retention' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRetentionType",
	;

method attributes() { }
method elements() {
	(qw(purpose recipient retention),
	);
}

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpStatementType"
	=> as __PACKAGE__;

1;
