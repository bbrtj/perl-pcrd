package PCRD::Module::Power;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Power';

sub check_capacity { ... }
sub init_capacity { ... }
sub get_capacity { ... }

sub check_status { ... }
sub init_status { ... }
sub get_status { ... }

sub check_battery_life { ... }
sub init_battery_life { ... }
sub get_battery_life { ... }

sub check_charge_threshold { ... }
sub init_charge_threshold { ... }
sub get_charge_threshold { ... }
sub set_charge_threshold { ... }

sub _build_features
{
	return {
		capacity => {
			desc => 'Current battery percent capacity',
			mode => 'ir',
		},
		status => {
			desc => 'Current charging status',
			mode => 'ir',
		},
		battery_life => {
			desc => 'Current battery life (minutes)',
			mode => 'ir',
		},
		charge_threshold => {
			desc => 'Battery charge start and stop threshold (start-stop)',
			mode => 'irw',
		},
	};
}

1;

