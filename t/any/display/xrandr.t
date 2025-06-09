use Test2::V0;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Display module's xrandr works
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		Display => {
			enabled => 1,
			all_features => 0,
			xrandr => {
				enabled => 1,
				command => 't/mock/bin/xrandr',
			},
		},
	},
);

my @cases = (
	[['Display', 'xrandr'], 'eDP-1: 1920x1080'],
	[['Display', 'xrandr', 'auto'], '1'],
	[['Display', 'xrandr'], 'HDMI-1: 1920x1080, eDP-1: 1920x1080'],
	[['Display', 'xrandr', 'O'], '1'],
	[['Display', 'xrandr', 'IP left'], '1'],
	[['Display', 'xrandr'], 'HDMI-1: 1920x1080, eDP-1: 1920x1080'],
	[['Display', 'xrandr', 'E'], '1'],
	[['Display', 'xrandr'], 'HDMI-1: 1920x1080'],
	[['Display', 'xrandr', 'O'], '1'],
	[['Display', 'xrandr'], 'eDP-1: 1920x1080'],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, 0.07, 0.2);
$pcrd->run_tests;

done_testing;

