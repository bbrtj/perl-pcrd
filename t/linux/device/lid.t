use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Device module's lid status works
################################################################################

my $lid = !!0;
sub get_lid { 'status: ' . (qw(closed open) [$lid]) }

my $pcrd = PCRDTest->new(
	config => {
		Device => {
			enabled => 1,
			all_features => 0,
			lid => {
				enabled => 1,
				pattern => PCRDFiles->prepare('lid', get_lid),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$lid = !$lid;
			PCRDFiles->update('lid', get_lid);
			$pcrd->test_message(['Device', 'lid'], $lid);
		},
	)
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

