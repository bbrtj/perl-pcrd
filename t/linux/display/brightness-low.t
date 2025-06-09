use Test2::V0;

use lib 't/lib';
use PCRDTest;
use PCRDFiles;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Display module's brightness works with very low values
# (due to logarithmic scale and integer casting of values)
################################################################################

my $current = 0;
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
				step => 5,
			},
		},
	},
);

my @cases = (
	[['Display', 'brightness'], 0],    # actual zero
	[['Display', 'brightness', 1], 1],
	[['Display', 'brightness'], 0],    # not a zero, but shows as zero on logarithmic scale
	[['Display', 'brightness', 1], 1],
	[['Display', 'brightness'], 0.1],
	[['Display', 'brightness', 1], 1],
	[['Display', 'brightness'], 0.15],
);

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

done_testing;

