use Test2::V0;
use File::Temp qw(tempfile);
use IO::Async::Timer::Periodic;

use PCRD;
use PCRD::Config::Memory;

################################################################################
# This tests whether the Power module works
################################################################################

my ($fh_capacity, $file_capacity) = tempfile;
my ($fh_status, $file_status) = tempfile;
my ($fh_energy, $file_energy) = tempfile;
my ($fh_charge_start, $file_charge_start) = tempfile;
my ($fh_charge_stop, $file_charge_stop) = tempfile;

my $test_ticks = 12;
my $capacity = 60;
my $status = !!1;
my $energy = 12500000;
my $start_thr = 50;
my $stop_thr = 50;

sub update
{
	my ($fh, $value) = @_;

	print {$fh} "$value\n";
	seek $fh, 0, 0;
}

sub update_files
{
	update $fh_capacity, --$capacity;
	update $fh_status, ($status = !$status) ? 'Charging' : 'Discharging';
	update $fh_energy, $energy -= 100;
	update $fh_charge_start, --$start_thr;
	update $fh_charge_stop, ++$stop_thr;
}

my $pcrd = PCRD->new(
	config => PCRD::Config::Memory->instance(
		name => 'mock',
		values => {
			'modules' => ['Power'],
			'Power.capacity.file' => $file_capacity,
			'Power.status.file' => $file_status,
			'Power.battery_life.file' => $file_energy,
			'Power.battery_life.probe_interval' => 0.02,
			'Power.charge_threshold.start_file' => $file_charge_start,
			'Power.charge_threshold.stop_file' => $file_charge_stop,
		}
	)
);

# expected battery life with current setup
my @expected_life = ((-1) x 4, (41) x 2, (31) x 2, (27) x 2, (26) x 2);

update_files;
my $timer = IO::Async::Timer::Periodic->new(
	interval => 0.01,
	on_tick => sub {
		$pcrd->stop if --$test_ticks == 0;
		update_files;

		subtest "testing tick $test_ticks" => sub {
			is $pcrd->{modules}{Power}->get_capacity, $capacity, 'capacity ok';
			is $pcrd->{modules}{Power}->get_status, $status, 'status ok';
			is $pcrd->{modules}{Power}->get_charge_threshold, "$start_thr-$stop_thr", 'charge threshold ok';
			is $pcrd->{modules}{Power}->get_battery_life, shift(@expected_life), 'battery life ok';
		};
	},
)->start;

$pcrd->{loop}->add($timer);

$pcrd->start;
done_testing;

