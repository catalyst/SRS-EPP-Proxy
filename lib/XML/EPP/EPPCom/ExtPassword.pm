
package SRS::EPP::Message::EPPCom::ExtPassword;

use Moose::Role;
use MooseX::Method::Signatures;
use Moose::Util::TypeConstraints;
our $SCHEMA_PKG = "SRS::EPP::Message::EPPCom";

# <any namespace="##other"> maps to MessageNode; it's a free for all!
with 'SRS::EPP::MessageNode';

subtype "${SCHEMA_PKG}::extAuthInfoType"
	=> as __PACKAGE__;

1;
