package PCRD::Module::Linux::System;

use v5.14;
use warnings;

use Time::Piece;

use parent 'PCRD::Module::System';

sub prepare_uptime
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{files}} = glob $feature->{config}{pattern};
}

sub check_uptime
{
	my ($self, $feature) = @_;

	return @{$feature->{vars}{files}} == 1
		&& -r $feature->{vars}{files}[0];
}

sub get_uptime
{
	my ($self, $feature) = @_;

	my $updata = PCRD::Util::slurp_1($feature->{vars}{files}[0]);
	my ($sec, $idle) = split /\s+/, $updata;

	my $days = int($sec / 60 / 60 / 24);
	my $hours = int($sec / 60 / 60) % 24;
	my $minutes = int($sec / 60) % 60;

	return sprintf $feature->{config}{format}, $days, $hours, $minutes;
}

sub _build_features
{
	my ($self) = @_;
	my $features = $self->SUPER::_build_features;

	$features->{uptime}{info} = 'System uptime is read from a file usually found under /proc directory';
	$features->{uptime}{config} = {
		%{$features->{uptime}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/proc/uptime',
		},
	};

	return $features;
}

1;

