use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Performance module's memory works
################################################################################

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Performance => {
		enabled => 1,
		all_features => 0,
		memory => {
			enabled => 1,
			pattern => 't/mock/proc/meminfo',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'memory'], 0.183607);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

