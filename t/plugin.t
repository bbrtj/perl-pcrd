use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the plugin works
################################################################################

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	TestPlugin => {
		enabled => 1,
		plugin => './t/lib/plugin.pm',
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['TestPlugin', 'something'], 'plugin works');
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

