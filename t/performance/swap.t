use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Performance module's swap works
################################################################################

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Performance => {
		enabled => 1,
		all_features => 0,
		swap => {
			enabled => 1,
			file => 't/mock/proc/meminfo',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'swap', 'r'], 0.000297);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

