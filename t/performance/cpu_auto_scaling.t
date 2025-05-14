use Test2::V0;
use IO::Async::Timer::Periodic;
use IO::Async::Timer::Countdown;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Performance module's cpu_auto_scaling works
################################################################################

my $status = !!1;
sub get_status { qw(Discharging Charging) [$status] }
my $scaling = 0;
sub get_scaling { qw(on_ac on_battery) [$scaling % 2] }

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	probe_interval => 0.01,
	Power => {
		enabled => 1,
		all_features => 0,
		status => {
			enabled => 1,
			pattern => $pcrd->prepare_tmpfile('status', get_status),
		},
	},
	Performance => {
		enabled => 1,
		all_features => 0,
		cpu_scaling => {
			enabled => 1,
			file => $pcrd->prepare_tmpfile('scaling', get_scaling),
		},
		cpu_auto_scaling => {
			enabled => 1,
			ac => 'on_ac',
			battery => 'on_battery',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Countdown->new(
		delay => 0.07,
		on_expire => sub {
			$status = !$status;
			$scaling++;
			$pcrd->update('status', get_status);
		},
	)->start
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'cpu_scaling', 'r'], get_scaling);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

