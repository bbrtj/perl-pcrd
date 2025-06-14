use Test2::V0;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Device module's suspend works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Device => {
			enabled => 1,
			all_features => 0,
			suspend => {
				enabled => 1,
				pattern => PCRDFiles->prepare('suspend', 'freeze mem disk'),
				state => 'disk',
			},
		},
	},
);

my @cases = (
	[['Device', 'suspend', PCRD::Protocol::TRUE], PCRD::Protocol::TRUE],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

is(PCRDFiles->contents('suspend'), 'disk', 'suspend ok');

done_testing;

