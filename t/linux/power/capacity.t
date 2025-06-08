use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Power module's capacity works
################################################################################

my $capacity = 60;

my $pcrd = PCRDTest->new(
	config => {
		Power => {
			enabled => 1,
			all_features => 0,
			capacity => {
				enabled => 1,
				pattern => PCRDFiles->prepare('capacity', $capacity),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$capacity -= 11;
			PCRDFiles->update('capacity', $capacity);
			$pcrd->test_message(['Power', 'capacity'], $capacity);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

