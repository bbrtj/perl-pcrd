package PCRD::Module::Any::Device;

use v5.14;
use warnings;

use PCRD::Util;

use parent 'PCRD::Module';

use constant name => 'Device';

sub get_lid { ... }

sub set_suspend { ... }

# no real way to check if the command works without running it
sub set_poweroff
{
	my ($self, $feature, $value) = @_;

	return PCRD::Util::execute_if_true(
		$value,
		sub {
			PCRD::Util::slurp_command($feature->config->{command});
		}
	);
}

# no real way to check if the command works without running it
sub set_reboot
{
	my ($self, $feature, $value) = @_;

	return PCRD::Util::execute_if_true(
		$value,
		sub {
			PCRD::Util::slurp_command($feature->config->{command});
		}
	);
}

sub _build_features
{
	return {
		lid => {
			desc => 'Get current state of the device lid',
			mode => 'r',
		},
		suspend => {
			desc => 'Suspends the machine',
			mode => 'w',
		},
		poweroff => {
			desc => 'Powers off the machine',
			mode => 'w',
			config => {
				command => {
					desc => 'Poweroff command',
					value => 'poweroff',
				},
			},
		},
		reboot => {
			desc => 'Reboots the machine',
			mode => 'w',
			config => {
				command => {
					desc => 'Reboot command',
					value => 'reboot',
				},
			},
		},
	};
}

1;

