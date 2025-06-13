package PCRD::Module::Any::FailedCheck;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'FailedCheck';

sub check_test
{
	return ['config', 'part'];
}

sub init_test
{
	# never executed
}

sub _build_features
{
	return {
		test => {
			desc => 'check always fails',
			mode => 'i',
		},
	};
}

1;

