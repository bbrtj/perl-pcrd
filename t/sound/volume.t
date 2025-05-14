use Test2::V0;
use IO::Async::Timer::Periodic;

use lib 't/lib';
use PCRDTest;

################################################################################
# This tests whether the Sound module's volume works
################################################################################

# hardcoded in pactl mock
my $volume = 0.5;

my $pcrd = PCRDTest->new;
$pcrd->create_daemon(
	Sound => {
		enabled => 1,
		all_features => 0,
		volume => {
			enabled => 1,
			command => 't/mock/bin/pactl',
		},
	},
);

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.04,
		on_tick => sub {
			$pcrd->test_message(['Sound', 'volume', 'r'], $volume);
			$pcrd->test_message(['Sound', 'volume', 'w', '1'], 1);
			$pcrd->test_message(['Sound', 'volume', 'r'], $volume + 0.05);
			$pcrd->test_message(['Sound', 'volume', 'w', '-1'], 1);
		},
	)->start
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start(0.1, 0.2);
$pcrd->run_tests;

done_testing;

