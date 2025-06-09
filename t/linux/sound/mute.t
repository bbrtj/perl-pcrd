use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Sound module's mute works
################################################################################

# hardcoded in pactl mock
my $muted = !!0;

my $pcrd = PCRDTest->new(
	config => {
		Sound => {
			enabled => 1,
			all_features => 0,
			command => 't/mock/bin/pactl',
			mute => {
				enabled => 1,
			},
		},
	},
);

my @cases = (
	[['Sound', 'mute'], $muted],
	[['Sound', 'mute', '1'], 1],
	[['Sound', 'mute'], !$muted],
	[['Sound', 'mute', 'toggle'], 1],
	[['Sound', 'mute'], $muted],
	[['Sound', 'mute', 'toggle'], 1],
	[['Sound', 'mute'], !$muted],
	[['Sound', 'mute', '0'], 1],
	[['Sound', 'mute'], $muted],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, undef, 0.2);
$pcrd->run_tests;

done_testing;

