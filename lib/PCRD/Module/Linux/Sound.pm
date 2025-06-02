package PCRD::Module::Linux::Sound;

use v5.14;
use warnings;

use Future;
use List::Util qw(sum);

use parent 'PCRD::Module::Sound';

sub _load_config
{
	my ($self) = @_;
	my $config = $self->SUPER::_load_config;

	$config->{command} = $self->config_obj->get_value('command', 'pactl');
	return $config;
}

sub check_volume
{
	my ($self, $feature) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($self->config->{command}, 'info');
	};

	return ['command', $ex || '(returned nothing)'] unless !$ex && @lines > 0;
	return undef;
}

sub get_volume
{
	my ($self, $feature) = @_;

	return $self->owner->broadcast($self->config->{command}, 'get-sink-volume', '@DEFAULT_SINK@')
		->then(
			sub {
				my @volumes;
				foreach my $line (@_) {
					while ($line =~ m/(\d+)%/g) {
						push @volumes, $1;
					}
				}

				return -1
				unless @volumes > 0;

				return sum(@volumes) / @volumes / 100;
			}
		);
}

sub set_volume
{
	my ($self, $feature, $direction) = @_;

	die 'invalid direction: must be either 1 or -1 (up or down)'
		unless $direction && $direction =~ m/^[+-]?1$/;

	my $value = ($direction * $feature->config->{step}) . '%';
	$value = "+$value" if $direction == 1;

	return $self->owner->broadcast($self->config->{command}, 'set-sink-volume', '@DEFAULT_SINK@', $value)
		->then(sub { 1 });
}

sub check_mute
{
	my ($self, $feature) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($self->config->{command}, 'info');
	};

	return ['command', $ex || '(returned nothing)'] unless !$ex && @lines > 0;
	return undef;
}

sub get_mute
{
	my ($self, $feature) = @_;
	$self->owner->broadcast($self->config->{command}, 'get-sink-mute', '@DEFAULT_SINK@')
		->then(
			sub {
				foreach my $line (@_) {
					return !!1
					if $line =~ m/\byes\b/i;
				}

				return !!0;
			}
		);
}

sub set_mute
{
	my ($self, $feature, $value) = @_;
	$value = $value ? 1 : 0
		unless $value =~ m/toggle/i;

	return $self->owner->broadcast($self->config->{command}, 'set-sink-mute', '@DEFAULT_SINK@', $value)
		->then(sub { 1 });
}

1;

