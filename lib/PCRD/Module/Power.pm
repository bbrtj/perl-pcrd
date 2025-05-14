package PCRD::Module::Power;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Power';

sub check_capacity { ... }
sub get_capacity { ... }

sub check_charging { ... }
sub get_charging { ... }

sub check_charging_threshold { ... }
sub get_charging_threshold { ... }
sub set_charging_threshold { ... }

sub check_life { ... }
sub init_life { ... }
sub get_life { ... }

sub _build_features
{
	return {
		capacity => {
			desc => 'Current battery percent capacity',
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
		},
	};
}

1;

