use Test2::V0;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Display module's brightness works
################################################################################

my $current = 300;
my $max = 1000;

my $pcrd = PCRDTest->new(
	config => {
		Display => {
			enabled => 1,
			all_features => 0,
			brightness => {
				enabled => 1,
				now_pattern => PCRDFiles->prepare('current', $current),
				max_pattern => PCRDFiles->prepare('max', $max),
				step => 10,
			},
		},
	},
);

my @cases = (
	[['Display', 'brightness'], int(log($current) / log($max) * 100) / 100],
	[['Display', 'brightness', 1], PCRD::Protocol::TRUE],
	[['Display', 'brightness'], int(log($current) / log($max) * 100 + 10) / 100],
	[['Display', 'brightness', -1], PCRD::Protocol::TRUE],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

