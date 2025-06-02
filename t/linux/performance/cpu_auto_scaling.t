use Test2::V0;
use IO::Async::Timer::Periodic;
use IO::Async::Timer::Countdown;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

################################################################################
# This tests whether the Performance module's cpu_auto_scaling works
################################################################################

my $charging = !!1;
sub get_charging { qw(Discharging Charging) [$charging] }
my $scaling = 0;
sub get_scaling { qw(on_ac on_battery) [$scaling % 2] }

my $pcrd = PCRDTest->new(
	config => {
		probe_interval => 0.01,
		Power => {
			enabled => 1,
			all_features => 0,
			charging => {
				enabled => 1,
				pattern => PCRDFiles->prepare('charging', get_charging),
			},
		},
		Performance => {
			enabled => 1,
			all_features => 0,
			cpu_scaling => {
				enabled => 1,
				pattern => PCRDFiles->prepare('scaling', get_scaling),
			},
			cpu_auto_scaling => {
				enabled => 1,
				ac => 'on_ac',
				battery => 'on_battery',
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Countdown->new(
		delay => 0.07,
		on_expire => sub {
			$charging = !$charging;
			$scaling++;
			PCRDFiles->update('charging', get_charging);
		},
	)->start
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'cpu_scaling'], get_scaling);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

