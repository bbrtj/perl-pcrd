package PCRD::Module::Power;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Power';

sub check_capacity { ... }
sub get_capacity { ... }

sub check_status { ... }
sub get_status { ... }

sub check_battery_life { ... }
sub get_battery_life { ... }

sub check_charge_threshold { ... }
sub get_charge_threshold { ... }
sub set_charge_threshold { ... }

sub _build_features
{
	return {
		capacity => {
			desc => 'Current battery percent capacity',
			mode => 'r',
			info => undef,
		},
		status => {
			desc => 'Current charging status',
			mode => 'r',
			info => undef,
		},
		battery_life => {
			desc => 'Current battery life (minutes)',
			mode => 'r',
			info => undef,
		},
		charge_threshold => {
			desc => 'Battery charge start and stop threshold (start-stop)',
			mode => 'rw',
			info => undef,
		},
	};
}

1;

