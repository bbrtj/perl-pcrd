use Test2::V0;
use IO::Async::Timer::Periodic;

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
				pattern => 't/mock/proc/meminfo',
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'swap'], 0.000297);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

