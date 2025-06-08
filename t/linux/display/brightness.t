use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Display module's brightness works
################################################################################

my $current = 300;
my $max = 1000;

my $pcrd = PCRDTest->new(
	config => {
		Display => {
			enabled => 1,
			all_features => 0,
			brightness => {
				enabled => 1,
				now_pattern => PCRDFiles->prepare('current', $current),
				max_pattern => PCRDFiles->prepare('max', $max),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Display', 'brightness'], int(log($current) / log($max) * 100) / 100);
			$pcrd->test_message(['Display', 'brightness', 1], 1);
			$pcrd->test_message(['Display', 'brightness'], int(log($current) / log($max) * 100 + 10) / 100);
			$pcrd->test_message(['Display', 'brightness', -1], 1);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

