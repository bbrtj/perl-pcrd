use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

################################################################################
# This tests whether the Power module's charging thresholds work
################################################################################

my $start = 50;
my $stop = 55;

my $pcrd = PCRDTest->new(
	config => {
		Power => {
			enabled => 1,
			all_features => 0,
			charging_threshold => {
				enabled => 1,
				start_pattern => PCRDFiles->prepare('start', $start),
				stop_pattern => PCRDFiles->prepare('stop', $stop),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			PCRDFiles->update('start', --$start);
			PCRDFiles->update('stop', ++$stop);

			$pcrd->test_message(['Power', 'charging_threshold'], "$start-$stop");
			--$start;
			++$stop;
			$pcrd->test_message(['Power', 'charging_threshold', "$start-$stop"], 1);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

