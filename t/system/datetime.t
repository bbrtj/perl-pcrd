use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the System module's date and time work
################################################################################

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	System => {
		enabled => 1,
		all_features => 0,
		date => {
			enabled => 1,
			format => 'd%s',
		},
		time => {
			enabled => 1,
			format => 't%s',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['System', 'date'], 'd' . time);
			$pcrd->test_message(['System', 'time'], 't' . time);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

