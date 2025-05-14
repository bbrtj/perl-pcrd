package PCRD::Module::Display;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Display';

sub check_brightness { ... }
sub get_brightness { ... }
sub set_brightness { ... }

sub _build_features
{
	return {
		brightness => {
			desc => 'Get current display brightness as percent on logarithmic scale',
			mode => 'rw',
		},
	};
}

1;

