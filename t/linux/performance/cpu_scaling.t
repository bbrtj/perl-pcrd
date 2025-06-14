use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's cpu_scaling works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Performance => {
			enabled => 1,
			all_features => 0,
			cpu_scaling => {
				enabled => 1,
				pattern => PCRDFiles->prepare('scaling', 'performance'),
				available_pattern => PCRDFiles->prepare('available', 'performance powersave'),
			},
		},
	},
);

my @cases = (
	[['Performance', 'cpu_scaling'], 'performance'],
	[['Performance', 'cpu_scaling', 'powersave'], PCRD::Protocol::TRUE],
	[['Performance', 'cpu_scaling'], 'powersave'],
	[['Performance', 'cpu_scaling', 'performance'], PCRD::Protocol::TRUE],
	[['Performance', 'cpu_scaling'], 'performance'],
	[['Performance', 'cpu_scaling', 'wrong'], 'invalid argument, must be any of: performance, powersave', !!1],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

