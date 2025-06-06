package PCRD::Module::Performance;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Performance';

sub check_memory { ... }
sub get_memory { ... }

sub check_swap { ... }
sub get_swap { ... }

sub check_storage { ... }
sub get_storage { ... }

sub check_cpu { ... }
sub init_cpu { ... }
sub get_cpu { ... }

sub check_cpu_scaling { ... }
sub get_cpu_scaling { ... }
sub set_cpu_scaling { ... }

sub init_cpu_auto_scaling { ... }

sub _build_features
{
	return {
		memory => {
			desc => 'Get the current main memory usage',
			mode => 'r',
		},
		swap => {
			desc => 'Get current swap usage',
			mode => 'r',
		},
		storage => {
			desc => 'Get current storage usage',
			mode => 'r',
		},
		cpu => {
			desc => 'Get current cpu utilization',
			mode => 'ir',
		},
		cpu_scaling => {
			desc => 'Get current cpu frequency scaling governor',
			mode => 'rw',
		},
		cpu_auto_scaling => {
			desc => 'Automatically set cpu scaling based on charging status',
			mode => 'i',
			info =>
				'CPU scaling can be automatically adjusted based on whether the charger is plugged in. Requires charging feature from Power module and cpu_scaling feature from this module.',
			config => {
				ac => {
					desc => 'scaling governor on AC',
					value => 'performance',
				},
				battery => {
					desc => 'scaling governor on battery',
					value => 'powersave',
				},
			},
			dependencies => [
				'Power.charging',
				'Performance.cpu_scaling',
			],
		},
	};
}

1;

