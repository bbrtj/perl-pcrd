use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Power module's charging thresholds work
################################################################################

my $start = 50;
my $stop = 55;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Power => {
		enabled => 1,
		all_features => 0,
		charging_threshold => {
			enabled => 1,
			start_pattern => $pcrd->prepare_tmpfile('start', $start),
			stop_pattern => $pcrd->prepare_tmpfile('stop', $stop),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->update('start', --$start);
			$pcrd->update('stop', ++$stop);

			$pcrd->test_message(['Power', 'charging_threshold', 'r'], "$start-$stop");
			--$start;
			++$stop;
			$pcrd->test_message(['Power', 'charging_threshold', 'w', "$start-$stop"], 1);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

