# Setup data needed by EPP proxy integration tests

use strict;
use warnings;

use FindBin qw($Bin);

print `$Bin/../../../testing/bin/RegistrarTests srsregn $Bin/create`;
