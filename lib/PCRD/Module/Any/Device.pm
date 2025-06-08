package PCRD::Module::Any::Device;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Device';

sub check_lid { ... }
sub get_lid { ... }

sub _build_features
{
	return {
		lid => {
			desc => 'Get current state of the device lid',
			mode => 'r',
		},
	};
}

1;

