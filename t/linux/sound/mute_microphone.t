use Test2::V0;

use lib 't/lib';
use PCRDTest;

plan skip_all 'This test requires Linux'
	unless lc $^O eq 'linux';

################################################################################
# This tests whether the Sound module's mute_microphone works
################################################################################

# hardcoded in pactl mock
my $muted = !!0;

my $pcrd = PCRDTest->new(
	config => {
		Sound => {
			enabled => 1,
			all_features => 0,
			command => 't/mock/bin/pactl',
			mute_microphone => {
				enabled => 1,
			},
		},
	},
);

my @cases = (
	[['Sound', 'mute_microphone'], PCRD::Bool->new($muted)],
	[['Sound', 'mute_microphone', PCRD::Bool->new(!!1)], PCRD::Bool->new(!!1)],
	[['Sound', 'mute_microphone'], PCRD::Bool->new(!$muted)],
	[['Sound', 'mute_microphone', 'toggle'], PCRD::Bool->new(!!1)],
	[['Sound', 'mute_microphone'], PCRD::Bool->new($muted)],
	[['Sound', 'mute_microphone', 'toggle'], PCRD::Bool->new(!!1)],
	[['Sound', 'mute_microphone'], PCRD::Bool->new(!$muted)],
	[['Sound', 'mute_microphone', PCRD::Bool->new(!!0)], PCRD::Bool->new(!!1)],
	[['Sound', 'mute_microphone'], PCRD::Bool->new($muted)],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, undef, 0.2);
$pcrd->run_tests;

done_testing;

