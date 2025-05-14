use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Display module's brightness works
################################################################################

my $current = 300;
my $max = 1000;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Display => {
		enabled => 1,
		all_features => 0,
		brightness => {
			enabled => 1,
			now_pattern => $pcrd->prepare_tmpfile('current', $current),
			max_pattern => $pcrd->prepare_tmpfile('max', $max),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Display', 'brightness', 'r'], int(log($current) / log($max) * 100) / 100);
			$pcrd->test_message(['Display', 'brightness', 'w', 1], int(log($current) / log($max) * 100 + 10) / 100);
			$pcrd->test_message(['Display', 'brightness', 'w', -1], int(log($current) / log($max) * 100) / 100);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

