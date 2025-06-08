use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Power module's ac status works
################################################################################

my $ac = 0;

my $pcrd = PCRDTest->new(
	config => {
		Power => {
			enabled => 1,
			all_features => 0,
			ac => {
				enabled => 1,
				pattern => PCRDFiles->prepare('ac', $ac),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$ac = ($ac + 1) % 2;
			PCRDFiles->update('ac', $ac);
			$pcrd->test_message(['Power', 'ac'], !!$ac);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

