package PCRD::Module::Any::TestPlugin;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'TestPlugin';

sub get_something
{
	my ($self, $feature) = @_;

	return 'plugin works';
}

sub _build_features
{
	return {
		something => {
			desc => 'test the plugin',
			mode => 'r',
		},
	};
}

1;

