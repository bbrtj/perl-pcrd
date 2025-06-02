use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

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

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.06,
		on_tick => sub {
			$pcrd->test_message(['Sound', 'mute'], $muted);
			$pcrd->test_message(['Sound', 'mute', '1'], 1);
			$pcrd->test_message(['Sound', 'mute'], !$muted);
			$pcrd->test_message(['Sound', 'mute', 'toggle'], 1);
			$pcrd->test_message(['Sound', 'mute'], $muted);
			$pcrd->test_message(['Sound', 'mute', 'toggle'], 1);
			$pcrd->test_message(['Sound', 'mute'], !$muted);
			$pcrd->test_message(['Sound', 'mute', '0'], 1);
			$pcrd->test_message(['Sound', 'mute'], $muted);
		},
	)->start
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start(0.1, 0.2);
$pcrd->run_tests;

done_testing;

