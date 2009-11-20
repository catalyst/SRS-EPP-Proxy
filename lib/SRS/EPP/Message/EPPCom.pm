
package SRS::EPP::Message::EPPCom;

use Moose;
use MooseX::Method::Signatures;

# this file does not implement a document format or a node, so it
# doesn't consume the SRS::EPP::Message role.

use constant XSI_XMLNS => "http://www.w3.org/2001/XMLSchema-instance";

use Moose::Util::TypeConstraints;

our $PKG = "SRS::EPP::Message::EPPCom";

#=====================================================================
#  eppcom-1.0.xsd mapping to types
#=====================================================================
# see EPP.pm, nearby, for introdutory explanatory notes

# this is a custom mapping.  Probably many of them will be for this
# class, as our normal definition of what to call the classes - based
# on the element name in which they are used - falls down completely;
# this spec for the most part defines types for use by the other
# standards.

# "AuthInfo" is usually introduced with a <pw> tag, so we'll call it
# Password
use SRS::EPP::Message::EPPCom::Password;
subtype "${PKG}::pwAuthInfoType" => as => "${PKG}::Password";

# <ext>, but it's basically still a password.
use SRS::EPP::Message::EPPCom::ExtPassword;
subtype "${PKG}::extAuthInfoType" => as => "${PKG}::ExtPassword";

subtype "${PKG}::reasonBaseType" =>
	as => "PRANG::XMLSchema::token",
	where {
		length($_) >= 1 and length($_) <= 32;
	};

use SRS::EPP::Message::EPPCom::Reason;
subtype "${PKG}::reasonType" => as => "${PKG}::Reason";

subtype "${PKG}::clIDType" =>
	as => "PRANG::XMLSchema::token",
	where {
		length($_) >= 3 and length($_) <= 16;
	};

subtype "${PKG}::labelType" =>
	as => "PRANG::XMLSchema::token",
	where {
		length($_) >= 1 and length($_) <= 255;
	};

# I call "hack" on this next one ;)
subtype "${PKG}::minTokenType" =>
	as => "PRANG::XMLSchema::token",
	where {
		length($_) >= 1;
	};

subtype "${PKG}::roidType" =>
	as => "PRANG::XMLSchema::token",
	where {
		m{^(?:[^\p{P}\p{Z}\p{C}]|_){1,80}-[^\p{P}\p{Z}\p{C}]{1,8}};
	};

subtype "${PKG}::trStatusType" =>
	as => "PRANG::XMLSchema::token",
	where {
		m{^(?:clientApproved|clientCancelled|clientRejected
		  |pending|serverApproved|serverCancelled)$}x;
	};

1;
