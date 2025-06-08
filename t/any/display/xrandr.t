use Test2::V0;
use IO::Async::Timer::Periodic;

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

my @messages = (
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

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.07,
		on_tick => sub {
			$pcrd->test_message(@{shift @messages})
				if @messages;
		},
	)->start
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start(0.8, 0.2);
$pcrd->run_tests;

done_testing;

