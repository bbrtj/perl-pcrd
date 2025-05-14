use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Performance module's cpu works
################################################################################

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	probe_interval => 0.01,
	Performance => {
		enabled => 1,
		all_features => 0,
		cpu => {
			enabled => 1,
			file => 't/mock/proc/stat',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'cpu', 'r'], 0.030886);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

