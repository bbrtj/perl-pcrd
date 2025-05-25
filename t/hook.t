use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the minimal hook system works
################################################################################

my $hook_ran;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	System => {
		enabled => 1,
		all_features => 0,
		time => {
			enabled => 1,
			format => 'CONST',
		},
	},
);

$pcrd->{pcrd}->module('System')->feature('time')->add_execute_hook(
	sub {
		$hook_ran = [@_];
	}
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['System', 'time'], 'CONST');
		},
	)->start
);

$pcrd->start(0.1);
$pcrd->run_tests;

is $hook_ran, ['r', undef, 'CONST'], 'hook was executed ok';

done_testing;

