package PCRD::Module::Power;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Power';

sub check_capacity { ... }
sub init_capacity { ... }
sub get_capacity { ... }

sub check_charging { ... }
sub init_charging { ... }
sub get_charging { ... }

sub check_charging_threshold { ... }
sub init_charging_threshold { ... }
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
			mode => 'ir',
		},
		charging => {
			desc => 'Current charging status',
			mode => 'ir',
		},
		charging_threshold => {
			desc => 'Battery charging start and stop threshold (start-stop)',
			mode => 'irw',
		},
		life => {
			desc => 'Current battery life (minutes)',
			mode => 'ir',
		},
	};
}

1;

