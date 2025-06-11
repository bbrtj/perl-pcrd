use Test2::V0;

use lib 't/lib';
use PCRD::Util;
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Device module's poweroff and reboot work
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Device => {
			enabled => 1,
			all_features => 0,
			poweroff => {
				enabled => 1,
				command => 't/mock/bin/run-counter',
			},
			reboot => {
				enabled => 1,
				command => 't/mock/bin/run-counter',
			},
		},
	},
);

my @cases = (
	[['Device', 'poweroff', 1], 1],
	[['Device', 'reboot', 1], 1],
);

PCRD::Util::slurp_command('t/mock/bin/run-counter', 'reset');

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

is [PCRD::Util::slurp_command('t/mock/bin/run-counter')], ['2'], 'command run count ok';

done_testing;

