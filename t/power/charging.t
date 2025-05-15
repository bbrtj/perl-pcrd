use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Power module's charging status works
################################################################################

my $charging = !!0;
sub get_charging { qw(Discharging Charging) [$charging] }

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Power => {
		enabled => 1,
		all_features => 0,
		charging => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('charging', get_charging),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$charging = !$charging;
			$pcrd->update('charging', get_charging);
			$pcrd->test_message(['Power', 'charging'], $charging);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

