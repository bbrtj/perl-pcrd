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
			},
		},
	},
);

my @cases = (
	[['Performance', 'cpu_scaling'], 'performance'],
	[['Performance', 'cpu_scaling', 'powersave'], 1],
	[['Performance', 'cpu_scaling'], 'powersave'],
	[['Performance', 'cpu_scaling', 'performance'], 1],
	[['Performance', 'cpu_scaling'], 'performance'],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

