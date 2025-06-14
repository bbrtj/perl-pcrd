use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's cpu works when values do not
# change (division by zero error)
################################################################################

my $cpu_utilized_base = 10000;
my $cpu_utilized = 500;
my $cpu_idle_base = 100000;
my $cpu_idle = 1000;

sub get_stat
{
	$cpu_utilized_base += $cpu_utilized;
	$cpu_idle_base += $cpu_idle;
	return join ' ', 'cpu', $cpu_utilized_base - 50, 30, 20, $cpu_idle_base;
}

my $pcrd = PCRDTest->new(
	config => {
		probe_interval => 0.01,
		Performance => {
			enabled => 1,
			all_features => 0,
			cpu => {
				enabled => 1,
				pattern => PCRDFiles->prepare('stat', get_stat),
			},
		},
	},
);

my @cases = (
	[['Performance', 'cpu'], -1]
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

