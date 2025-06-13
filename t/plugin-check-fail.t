use Test2::V0;

BEGIN {
	$ENV{PCRD_CHECK_FATAL} = 1;
	$ENV{PCRD_DIR} = './t/lib';
}

use lib 't/lib';
use PCRDTest;
use PCRD::X::CheckFailed;
use PCRD::Util;

################################################################################
# This tests whether the plugin => 1 and fatal checks work
################################################################################

my $pcrd = PCRDTest->new(
	config => {
		FailedCheck => {
			enabled => 1,
			plugin => 1,
		},
	}
);

my $ex = PCRD::Util::try {
	$pcrd->start;
};

ok($ex, 'exception present ok');
isa_ok($ex, 'PCRD::X::CheckFailed');
is($ex->message, 'config', 'message ok');
is($ex->feature->name, 'test', 'feature ok');
is($ex->feature_part, 'part', 'part ok');

my $str = "$ex";
like $str, qr{\Q'FailedCheck.test' will not work\E}, 'feature name ok';
like $str, qr{\QBad configuration value 'part'\E}, 'feature part name ok';
like $str, qr{\Qcheck always fails\E}, 'feature desc ok';
like $str, qr{\Q(no config)\E}, 'feature config ok';

done_testing;

