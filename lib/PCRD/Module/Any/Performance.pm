package PCRD::Module::Any::Performance;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Performance';

sub get_memory { ... }

sub get_swap { ... }

sub get_storage { ... }

sub init_cpu { ... }
sub get_cpu { ... }

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
			desc => 'Automatically set cpu scaling based on ac status',
			mode => 'i',
			info =>
				'CPU scaling can be automatically adjusted based on whether the ac is present. Requires ac feature from Power module and cpu_scaling feature from this module.',
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
				'Power.ac',
				'Performance.cpu_scaling',
			],
		},
	};
}

1;

