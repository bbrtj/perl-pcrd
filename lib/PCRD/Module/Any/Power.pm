package PCRD::Module::Any::Power;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Power';

sub get_capacity { ... }

sub get_ac { ... }

sub get_charging { ... }

sub get_charging_threshold { ... }
sub set_charging_threshold { ... }

sub init_life { ... }
sub get_life { ... }

sub _build_features
{
	return {
		capacity => {
			desc => 'Current battery percent capacity',
			mode => 'r',
		},
		ac => {
			desc => 'Current alternating current status',
			mode => 'r',
		},
		charging => {
			desc => 'Current charging status',
			mode => 'r',
		},
		charging_threshold => {
			desc => 'Battery charging start and stop threshold (start-stop)',
			mode => 'rw',
		},
		life => {
			desc => 'Current battery life (minutes)',
			mode => 'ir',
			config => {
				measurement_window => {
					desc => 'time window (in minutes) which will be used for the calculation',
					value => 10,
				},
			},
		},
	};
}

1;

