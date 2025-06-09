use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's storage works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Performance => {
			enabled => 1,
			all_features => 0,
			storage => {
				enabled => 1,
				command => 't/mock/bin/df',
			},
		},
	},
);

my @cases = (
	[['Performance', 'storage'], 0.18016],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

