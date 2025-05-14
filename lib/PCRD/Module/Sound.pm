package PCRD::Module::Sound;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Sound';

sub check_volume { ... }
sub get_volume { ... }
sub set_volume { ... }

sub _build_features
{
	return {
		volume => {
			desc => 'Get current sound volume of the default audio sink',
			mode => 'rw',
		},
	};
}

1;

