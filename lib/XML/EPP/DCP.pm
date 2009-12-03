
package XML::EPP::DCP::Expiry;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
use PRANG::XMLSchema::Types;

our $SCHEMA_PKG = "XML::EPP";

# hmm, choice with simpleTypes can't be mapped quite the same..
has 'absolute' =>
	is => "rw",
	isa => "PRANG::XMLSchema::dateTime",
	predicate => "has_absolute",
	clearer => "clear_absolute",
	trigger => sub { $_[0]->is_abs_or_rel("absolute") },
	;

has 'relative' =>
	is => "rw",
	isa => "PRANG::XMLSchema::duration",
	predicate => "has_relative",
	clearer => "clear_relative",
	trigger => sub { $_[0]->is_abs_or_rel("relative") },
	;

has_element 'abs_or_rel' =>
	is => "rw",
	isa => "PRANG::XMLSchema::duration|PRANG::XMLSchema::dateTime",
	xml_nodeName => {
		"absolute" => "PRANG::XMLSchema::dateTime",
		"relative" => "PRANG::XMLSchema::duration",
	},
	xml_nodeName_attr => "is_abs_or_rel",
	;

method is_abs_or_rel( Str $abs_or_rel? where { m{^(relative|absolute)$} } ) {
	if ( defined $abs_or_rel ) {
		if ( $abs_or_rel eq "relative" ) {
			$self->clear_absolute;
		}
		else {
			$self->clear_relative;
		}
	}
	else {
		if ( $self->has_relative ) {
			"relative";
		}
		elsif ( $self->has_absolute ) {
			"absolute";
		}
		else {
			die "neither absolute nor relative time in $self";
		}
	}
}

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::dcpExpiryType"
	=> as __PACKAGE__;

package XML::EPP::DCP::Ours;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

subtype "${SCHEMA_PKG}::dcpRecDescType"
	=> as "PRANG::XMLSchema::token"
	=> where {
		length($_) and length($_) <= 255;
	};

has_element 'recDesc' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRecDescType",
	predicate => "has_recDesc",
	;

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::dcpOursType"
	=> as __PACKAGE__;


package XML::EPP::DCP::Recipient;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

for my $recipient ( qw(other ours public same unrelated) ) {

	my $type = $recipient eq "ours" ?
		"ArrayRef[${SCHEMA_PKG}::dcpOursType]" : "Bool";

	has_element $recipient =>
		(is => "rw",
		 isa => $type,
		 predicate => "has_$recipient",
		 );
}

with 'XML::EPP::Node';

subtype "${SCHEMA_PKG}::dcpRecipientType"
	=> as __PACKAGE__;

package XML::EPP::DCP::Access;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

my @access_enum = qw(all none null other personal personalAndOther);
enum "${SCHEMA_PKG}::dcpAccessType::enum" => @access_enum;

has 'access' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpAccessType::enum",
	trigger => sub { $_[0]->access_node(1) },
	;

has_element 'access_node' =>
	is => "rw",
	isa => "Bool",
	xml_nodeName => { map { $_ => "Bool" } @access_enum },
	xml_nodeName_attr => "access",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpAccessType"
	=> as __PACKAGE__;

package XML::EPP::DCP;

use Moose;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
use PRANG::Graph;
our $SCHEMA_PKG = "XML::EPP";

has_element 'access' =>
	is => "rw",
	isa => "XML::EPP::DCP::Access",
	;

has_element 'statement' =>
	is => "rw",
	isa => "ArrayRef[${SCHEMA_PKG}::DCP::Statement]",
	;

has_element 'expiry' =>
	is => "rw",
	predicate => "has_expiry",
	isa => "${SCHEMA_PKG}::dcpExpiryType",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpType"
	=> as __PACKAGE__;

package XML::EPP::DCP::Purpose;

use Moose;
our $SCHEMA_PKG = "XML::EPP";
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;

has_element $_ =>
	is => "rw",
	isa => "Bool"
	for qw(admin contact other prov);

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpPurposeType"
	=> as __PACKAGE__;

package XML::EPP::DCP::Retention;

use Moose;
our $SCHEMA_PKG = "XML::EPP";
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;

my @retention_types = qw(business indefinite legal none stated);
enum "${SCHEMA_PKG}::dcpRetentionType::enum"
	=> @retention_types;

with "${SCHEMA_PKG}::Node";

has 'retention' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRetentionType::enum",
	trigger => sub {
		$_[0]->has_retention(1);
	};

has_element 'has_retention' =>
	is => "rw",
	isa => "Bool",
	xml_nodeName => { map { $_ => "Bool" } @retention_types },
	xml_nodeName_attr => "retention",
	;

subtype "${SCHEMA_PKG}::dcpRetentionType"
	=> as __PACKAGE__;

package XML::EPP::DCP::Statement;

use Moose;
our $SCHEMA_PKG = "XML::EPP";
use Moose::Util::TypeConstraints;
use MooseX::Method::Signatures;
use PRANG::Graph;

has_element 'purpose' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpPurposeType",
	;

has_element 'recipient' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRecipientType",
	;

has_element 'retention' =>
	is => "rw",
	isa => "${SCHEMA_PKG}::dcpRetentionType",
	;

with "${SCHEMA_PKG}::Node";

subtype "${SCHEMA_PKG}::dcpStatementType"
	=> as __PACKAGE__;

1;
