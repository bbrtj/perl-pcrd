use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Performance module's cpu_scaling works
################################################################################

my $scaling = 1;
sub get_scaling { qw(performance powersave) [$scaling % 2] }

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Performance => {
		enabled => 1,
		all_features => 0,
		cpu_scaling => {
			enabled => 1,
			file => $pcrd->prepare_tmpfile('scaling', get_scaling),
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Performance', 'cpu_scaling', 'r'], get_scaling);
			$scaling++;
			$pcrd->test_message(['Performance', 'cpu_scaling', 'w', get_scaling], get_scaling);
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

done_testing;

