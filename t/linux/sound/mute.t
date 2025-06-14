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
	[['Sound', 'mute'], PCRD::Protocol::bool_to_value($muted)],
	[['Sound', 'mute', PCRD::Protocol::TRUE], PCRD::Protocol::TRUE],
	[['Sound', 'mute'], PCRD::Protocol::bool_to_value(!$muted)],
	[['Sound', 'mute', 'toggle'], PCRD::Protocol::TRUE],
	[['Sound', 'mute'], PCRD::Protocol::bool_to_value($muted)],
	[['Sound', 'mute', 'toggle'], PCRD::Protocol::TRUE],
	[['Sound', 'mute'], PCRD::Protocol::bool_to_value(!$muted)],
	[['Sound', 'mute', PCRD::Protocol::FALSE], PCRD::Protocol::TRUE],
	[['Sound', 'mute'], PCRD::Protocol::bool_to_value($muted)],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, undef, 0.2);
$pcrd->run_tests;

done_testing;

