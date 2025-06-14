use Test2::V0;
use Scalar::Util qw(blessed);

use lib 't/lib';
use PCRDTest;
use PCRD::X::CheckFailed;
use PCRD::Util;

################################################################################
# This tests whether an unfunctional plugin returns proper errors
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		FailedCheck => {
			enabled => 1,
			plugin => './t/lib/plugins/FailedCheck.pm',
		},
	}
);

my @cases = (
	[['FailedCheck', 'test'], 'feature is not functional', !!1],
	[['FailedCheck', 'test', 'x'], 'feature does not provide that action', !!1],
);

my $got_warn = 0;
$SIG{__WARN__} = sub {
	my $warn = shift;
	my $wanted = blessed $warn && $warn->isa('PCRD::X::CheckFailed');
	if ($wanted) {
		++$got_warn;
	}
	else {
		warn $warn;
	}
};

$pcrd->start_cases(\@cases);
$pcrd->run_tests;

is $got_warn, 1, 'warning ok';

done_testing;

