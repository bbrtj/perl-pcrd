use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Power module's battery life works
################################################################################

my $energy = 12500000;
my $ticks = 0;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	probe_interval => 0.01,
	Power => {
		enabled => 1,
		all_features => 0,
		battery_life => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('energy', $energy),
		},
	},
);

$pcrd->loop->add(
	IO::Async::Timer::Periodic->new(
		interval => 0.01,
		on_tick => sub {
			$energy -= 100;
			$pcrd->update('energy', $energy);

			if (++$ticks > 6) {
				$pcrd->test_message(['Power', 'battery_life', 'r'], sub { $_ >= 20 && $_ <= 21 });
			}
		},
	)->start
);

# 0.105 guarantees to get the final answer from the loop (periodic tick every 0.01 sec)
$pcrd->start(0.105);
$pcrd->run_tests;

done_testing;

