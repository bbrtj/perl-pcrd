use Test2::V0;
use IO::Async::Timer::Periodic;
use IO::Async::Timer::Countdown;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's cpu_auto_scaling works
################################################################################

my $ac = 1;
my $scaling = 0;
sub get_scaling { qw(on_ac on_battery) [$scaling % 2] }

my $pcrd = PCRDTest->new(
	config => {
		probe_interval => 0.01,
		Power => {
			enabled => 1,
			all_features => 0,
			ac => {
				enabled => 1,
				pattern => PCRDFiles->prepare('ac', $ac),
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
			$ac = ($ac + 1) % 2;
			$scaling++;
			PCRDFiles->update('ac', $ac);
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

