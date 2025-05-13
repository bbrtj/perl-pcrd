use Test2::V0;
use File::Temp qw(tempfile);
use IO::Async::Timer::Periodic;

use lib 't/lib';

use PCRDTest;

################################################################################
# This tests whether the Power module works
################################################################################

my $test_ticks = 0;
my $capacity = 60;
my $status = !!1;
my $energy = 12500000;
my $start_thr = 50;
my $stop_thr = 50;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	'modules' => ['Power'],
	'Power.capacity.file' => $pcrd->prepare_tmpfile('capacity', $capacity),
	'Power.status.file' => $pcrd->prepare_tmpfile('status', 'Charging'),
	'Power.battery_life.file' => $pcrd->prepare_tmpfile('energy', $energy),
	'Power.battery_life.probe_interval' => 0.02,
	'Power.charge_threshold.start_file' => $pcrd->prepare_tmpfile('start_thr', $start_thr),
	'Power.charge_threshold.stop_file' => $pcrd->prepare_tmpfile('stop_thr', $stop_thr),
);

sub update_files
{
	$pcrd->update(capacity => --$capacity);
	$pcrd->update(status => ($status = !$status) ? 'Charging' : 'Discharging');
	$pcrd->update(energy => $energy -= 100);
	$pcrd->update(start_thr => --$start_thr);
	$pcrd->update(stop_thr => ++$stop_thr);
}

my $timer = IO::Async::Timer::Periodic->new(
	interval => 0.01,
	on_tick => sub {
		if ($test_ticks++ == 12) {
			$pcrd->stop;
			return;
		}

		update_files;

		$pcrd->test_message(['Power', 'capacity', 'r'], $capacity, "tick $test_ticks");
		$pcrd->test_message(['Power', 'status', 'r'], $status, "tick $test_ticks");
		$pcrd->test_message(['Power', 'charge_threshold', 'r'], "$start_thr-$stop_thr", "tick $test_ticks");

		if ($test_ticks > 6) {
			$pcrd->test_message(['Power', 'battery_life', 'r'], sub { $_ > 20 && $_ < 40 }, "tick $test_ticks");
		}
	},
)->start;

$pcrd->loop->add($timer);

$pcrd->start;
$pcrd->run_tests;

done_testing;

