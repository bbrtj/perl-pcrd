use Test2::V0;
use IO::Async::Timer::Periodic;

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

$pcrd->add_test_timer(
	IO::Async::Timer::Periodic->new(
		interval => 0.06,
		on_tick => sub {
			$pcrd->test_message(['Sound', 'volume'], $volume);
			$pcrd->test_message(['Sound', 'volume', '1'], 1);
			$pcrd->test_message(['Sound', 'volume'], $volume + 0.05);
			$pcrd->test_message(['Sound', 'volume', '-1'], 1);
		},
	)->start
);

# perl script is called multiple times, so this needs extra finalization time
# window
$pcrd->start(0.1, 0.2);
$pcrd->run_tests;

done_testing;

