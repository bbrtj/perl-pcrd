use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Power module's charging status works
################################################################################

my $charging = !!0;
sub get_charging { qw(Discharging Charging) [$charging] }

my $pcrd = PCRDTest->new(
	config => {
		Power => {
			enabled => 1,
			all_features => 0,
			charging => {
				enabled => 1,
				pattern => PCRDFiles->prepare('charging', get_charging),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$charging = !$charging;
			PCRDFiles->update('charging', get_charging);
			$pcrd->test_message(['Power', 'charging'], $charging);
		},
	)
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

