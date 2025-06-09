use Test2::V0;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the minimal hook system works
################################################################################

my $hook_ran;

my $pcrd = PCRDTest->new(
	config => {
		System => {
			enabled => 1,
			all_features => 0,
			time => {
				enabled => 1,
				format => 'CONST',
			},
		},
	}
);

$pcrd->daemon->module('System')->feature('time')->add_execute_hook(
	sub {
		$hook_ran = [@_];
	}
);

my @cases = (
	[['System', 'time'], 'CONST'],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

is $hook_ran, ['r', undef, 'CONST'], 'hook was executed ok';

done_testing;

