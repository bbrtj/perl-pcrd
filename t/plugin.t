use Test2::V0;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the plugin works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		TestPlugin => {
			enabled => 1,
			plugin => './t/lib/plugin.pm',
		},
	}
);

my @cases = (
	[['TestPlugin', 'something'], 'plugin works'],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

