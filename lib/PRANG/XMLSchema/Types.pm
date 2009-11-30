
package PRANG::XMLSchema::Types;

use strict;
use Moose::Util::TypeConstraints;

subtype "PRANG::XMLSchema::normalizedString"
	=> as "Str"
	=> where { !m{[\n\r\t]} };

subtype "PRANG::XMLSchema::token"
	=> as "Str"
	=> where {
		!m{[\t\r\n]|^\s|\s$|\s\s};
	};

use Regexp::Common qw /URI/;
subtype "PRANG::XMLSchema::anyURI"
	=> as "Str"
	=> where {
		m{$RE{URI}}o;
	};

use I18N::LangTags qw(is_language_tag);
subtype "PRANG::XMLSchema::language"
	=> as "Str"
	=> where {
		is_language_tag($_);
	};

subtype "PRANG::XMLSchema::dateTime"
	=> as "Str"
	=> where {
		# from the XMLSchema spec... it'll do for now ;)
		m{
-?([1-9][0-9]{3,}|0[0-9]{3})
-(0[1-9]|1[0-2])
-(0[1-9]|[12][0-9]|3[01])
T(([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?|(24:00:00(\.0+)?))
(?:Z|(?:\+|-)(?:(?:0[0-9]|1[0-3]):[0-5][0-9]|14:00))?
	 }x;
	};

subtype "PRANG::XMLSchema::duration"
	=> as "Str"
	=> where {
		die "FIXME";
	};
1;
