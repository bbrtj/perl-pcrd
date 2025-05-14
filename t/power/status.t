use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Power module's status works
################################################################################

my $status = !!0;
sub get_status { qw(Discharging Charging) [$status] }

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Power => {
		enabled => 1,
		all_features => 0,
		status => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('status', get_status),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$status = !$status;
			$pcrd->update('status', get_status);
			$pcrd->test_message(['Power', 'status', 'r'], $status);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

