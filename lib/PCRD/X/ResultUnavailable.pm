package PCRD::X::ResultUnavailable;

use v5.14;
use warnings;

use PCRD::Mite;

extends 'PCRD::X::ExecutionFailed';

sub raise
{
	my ($self, $message) = @_;

	$self->SUPER::raise($message // 'result is not available');
}

1;

