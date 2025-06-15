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

sub get_string
{
	my ($edp, $hdmi, $zz) = map { $_ ? ' (active)' : '' } @_;
	return "HDMI-1$hdmi: 1920x1080, ZZ-1$zz: 3840x2160, eDP-1$edp: 1920x1080";
}

my @cases = (
	[['Display', 'xrandr'], get_string(1, 0, 1)],
	[['Display', 'xrandr', 'auto'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(1, 0, 0)],
	[['Display', 'xrandr', 'auto'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(1, 1, 0)],
	[['Display', 'xrandr', 'auto'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(1, 0, 0)],
	[['Display', 'xrandr', 'IP left'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(1, 1, 0)],
	[['Display', 'xrandr', 'E'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(0, 1, 0)],
	[['Display', 'xrandr', 'O'], PCRD::Bool->new(!!1)],
	[['Display', 'xrandr'], get_string(1, 0, 0)],
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start_cases(\@cases, 0.07, 0.2);
$pcrd->run_tests;

done_testing;

