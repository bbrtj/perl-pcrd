package PCRD::Module::Linux::Sound;

use v5.14;
use warnings;

use List::Util qw(sum);

use parent 'PCRD::Module::Sound';

sub check_volume
{
	my ($self, $feature) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($feature->{config}{command}, 'info');
	};

	return !$ex && @lines > 0;
}

sub get_volume
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp_command($feature->{config}{command}, 'get-sink-volume', '@DEFAULT_SINK@');
	my @volumes;
	foreach my $line (@lines) {
		while ($line =~ m/(\d+)%/g) {
			push @volumes, $1;
		}
	}

	return -1
		unless @volumes > 0;

	return sum(@volumes) / @volumes / 100;
}

sub set_volume
{
	my ($self, $feature, $direction) = @_;

	die 'invalid direction: must be either 1 or -1 (up or down)'
		unless $direction && $direction =~ m/^-?1$/;

	my $value = ($direction * 5) . '%';
	$value = "+$value" if $direction == 1;

	PCRD::Util::slurp_command($feature->{config}{command}, 'set-sink-volume', '@DEFAULT_SINK@', $value);
	return 1;
}

sub _build_features
{
	my ($self) = @_;
	my $features = $self->SUPER::_build_features;

	$features->{volume}{info} = 'Sound volume is controlled using pulseaudio program called pactl';
	$features->{volume}{config} = {
		%{$features->{volume}{config} // {}},
		command => {
			desc => 'pulseaudio command',
			value => 'pactl',
		},
	};

	return $features;
}

1;

