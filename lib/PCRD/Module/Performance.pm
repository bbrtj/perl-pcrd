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

sub check_cpu_auto_scaling { ... }
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
		},
	};
}

1;

