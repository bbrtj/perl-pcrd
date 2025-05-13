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
sub get_cpu { ... }

sub check_cpu_scaling { ... }
sub get_cpu_scaling { ... }
sub set_cpu_scaling { ... }

sub _build_features
{
	return {
		memory => {
			desc => 'Get the current main memory usage',
			mode => 'r',
			info => undef,
		},
		swap => {
			desc => 'Get current swap usage',
			mode => 'r',
			info => undef,
		},
		storage => {
			desc => 'Get current storage usage',
			mode => 'r',
			info => undef,
		},
		cpu => {
			desc => 'Get current cpu utilization',
			mode => 'r',
			info => undef,
		},
		cpu_scaling => {
			desc => 'Get current cpu frequency scaling governor',
			mode => 'rw',
			info => undef,
		},
	};
}

1;

