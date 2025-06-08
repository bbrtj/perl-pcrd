use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Power module's battery life works
################################################################################

my $energy = 12500000;
my $ticks = 0;

my $pcrd = PCRDTest->new(
	config => {
		probe_interval => 0.01,
		Power => {
			enabled => 1,
			all_features => 0,
			life => {
				enabled => 1,
				pattern => PCRDFiles->prepare('energy', $energy),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.01,
		on_tick => sub {
			$energy -= 100;
			PCRDFiles->update('energy', $energy);

			if (++$ticks > 6) {
				$pcrd->test_message(['Power', 'life'], sub { $_ >= 20 && $_ <= 21 });
			}
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

