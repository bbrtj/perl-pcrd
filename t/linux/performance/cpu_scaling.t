use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Performance module's cpu_scaling works
################################################################################

my $scaling = 1;
sub get_scaling { qw(performance powersave) [$scaling % 2] }

my $pcrd = PCRDTest->new(
	config => {
		Performance => {
			enabled => 1,
			all_features => 0,
			cpu_scaling => {
				enabled => 1,
				pattern => PCRDFiles->prepare('scaling', get_scaling),
			},
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'cpu_scaling'], get_scaling);
			$scaling++;
			$pcrd->test_message(['Performance', 'cpu_scaling', get_scaling], 1);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

