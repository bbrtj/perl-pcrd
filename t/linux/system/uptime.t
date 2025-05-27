use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the System module's uptime works
################################################################################

my $upsec = 16541;
my $idle = 5146;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	System => {
		enabled => 1,
		all_features => 0,
		uptime => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('uptime', "$upsec $idle"),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$upsec += 100;
			$pcrd->update('uptime', "$upsec $idle");

			my $d = int($upsec / 60 / 60 / 24);
			my $h = int($upsec / 60 / 60) % 24;
			my $m = int($upsec / 60) % 60;

			$pcrd->test_message(['System', 'uptime'], "${d}d ${h}h ${m}m");
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

