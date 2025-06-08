package PCRD::Module::Any::System;

use v5.14;
use warnings;

use Time::Piece;

use parent 'PCRD::Module';

use constant name => 'System';

sub get_time
{
	my ($self, $feature) = @_;

	return localtime->strftime($feature->config->{format});
}

sub get_date
{
	my ($self, $feature) = @_;

	return localtime->strftime($feature->config->{format});
}

sub check_uptime { ... }
sub get_uptime { ... }

sub _build_features
{
	return {
		time => {
			desc => 'Get current time',
			mode => 'r',
			info => 'Gets the current system time',
			config => {
				format => {
					desc => 'time format in strftime format',
					value => '%H:%M',
				},
			},
		},
		date => {
			desc => 'Get current date',
			mode => 'r',
			info => 'Gets the current system date',
			config => {
				format => {
					desc => 'date format in strftime format',
					value => '%e, %a',
				},
			},
		},
		uptime => {
			desc => 'Get current system uptime',
			mode => 'r',
			config => {
				format => {
					desc => 'sprintf format, where arguments are: days, hours, minutes',
					value => '%sd %sh %sm',
				},
			},
		},
	};
}

1;

