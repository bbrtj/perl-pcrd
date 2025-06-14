use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's swap works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Performance => {
			enabled => 1,
			all_features => 0,
			swap => {
				enabled => 1,
				pattern => 't/mock/proc/meminfo_no_swap',
			},
		},
	},
);

my @cases = (
	[['Performance', 'swap'], 'result is not available', !!1],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

