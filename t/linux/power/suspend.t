use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

################################################################################
# This tests whether the Power module's suspend works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Power => {
			enabled => 1,
			all_features => 0,
			suspend => {
				enabled => 1,
				pattern => PCRDFiles->prepare('suspend', 'freeze mem disk'),
				state => 'disk',
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.06,
		on_tick => sub {
			$pcrd->test_message(['Power', 'suspend', 1], 1);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

is(PCRDFiles->contents('suspend'), 'disk', 'suspend ok');

done_testing;

