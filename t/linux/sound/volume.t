use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Sound module's volume works
################################################################################

# hardcoded in pactl mock
my $volume = 0.5;

my $pcrd = PCRDTest->new(
	config => {
		Sound => {
			enabled => 1,
			all_features => 0,
			command => 't/mock/bin/pactl',
			volume => {
				enabled => 1,
				step => 5,
			},
		},
	},
);

my @cases = (
	[['Sound', 'volume'], $volume],
	[['Sound', 'volume', '1'], PCRD::Protocol::TRUE],
	[['Sound', 'volume'], $volume + 0.05],
	[['Sound', 'volume', '-1'], PCRD::Protocol::TRUE],
	[['Sound', 'volume'], $volume],
	[['Sound', 'volume', '+1'], PCRD::Protocol::TRUE],
	[['Sound', 'volume'], $volume + 0.05],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, undef, 0.2);
$pcrd->run_tests;

done_testing;

