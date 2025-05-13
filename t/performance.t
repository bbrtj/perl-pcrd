use Test2::V0;
use File::Temp qw(tempfile);
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Power module works
################################################################################

my $test_ticks = 0;
my $scaling = 'performance';

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	'modules' => ['Power', 'Performance'],
	'probe_interval' => 0.01,
	'Power.capacity.pattern' => $pcrd->prepare_tmpfile('capacity', 1),
	'Power.status.pattern' => $pcrd->prepare_tmpfile('status', 'Charging'),
	'Power.battery_life.pattern' => $pcrd->prepare_tmpfile('energy', 1),
	'Power.charge_threshold.start_pattern' => $pcrd->prepare_tmpfile('start_thr', 1),
	'Power.charge_threshold.stop_pattern' => $pcrd->prepare_tmpfile('stop_thr', 1),
	'Performance.memory.file' => 't/mock/proc/meminfo',
	'Performance.storage.command' => 't/mock/bin/mockdf',
	'Performance.cpu.file' => 't/mock/proc/stat',
	'Performance.cpu_scaling.file' => $pcrd->prepare_tmpfile('cpu_scaling', $scaling),
);

my $got_powersave;
my $timer = IO::Async::Timer::Periodic->new(
	interval => 0.01,
	on_tick => sub {
		if ($test_ticks++ >= 12) {
			$pcrd->stop if $test_ticks >= 20;
			return;
		}

		$pcrd->test_message(['Performance', 'memory', 'r'], 0.183607, "tick $test_ticks");
		$pcrd->test_message(['Performance', 'swap', 'r'], 0.000297, "tick $test_ticks");
		$pcrd->test_message(['Performance', 'storage', 'r'], 0.18016, "tick $test_ticks");
		$pcrd->test_message(['Performance', 'cpu', 'r'], 0.030886, "tick $test_ticks");
		$pcrd->test_message(
			['Performance', 'cpu_scaling', 'r'],
			sub {
				if ($scaling eq 'powersave') {
					$got_powersave = !!1;
					return !!1;
				}
				else {
					return $_ eq $scaling;
				}
			},
			"tick $test_ticks"
		);

		if ($test_ticks > 6) {
			$pcrd->update('status', 'Discharging');
			$scaling = 'powersave';
		}
	},
)->start;

$pcrd->loop->add($timer);

$pcrd->start;
$pcrd->run_tests;
ok $got_powersave, 'scaling turned to powersave';

done_testing;

