use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Device module's lid status works
################################################################################

my $lid = !!0;
sub get_lid { 'status: ' . (qw(closed open) [$lid]) }

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Device => {
		enabled => 1,
		all_features => 0,
		lid => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('lid', get_lid),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$lid = !$lid;
			$pcrd->update('lid', get_lid);
			$pcrd->test_message(['Device', 'lid'], $lid);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

