package PCRD::Module::Linux::Sound;

use v5.14;
use warnings;

use Future;
use List::Util qw(sum);

use parent 'PCRD::Module::Any::Sound';

sub _load_config
{
	my ($self) = @_;
	my $config = $self->SUPER::_load_config;

	$config->{command} = $self->config_obj->get_value('command', 'pactl');
	return $config;
}

# cache command checking, since all features use the same command
sub _check
{
	my ($self) = @_;

	return $self->{_check}
		if exists $self->{_check};

	return $self->owner->broadcast($self->config->{command}, 'info')
		->then(
			sub {
				return ['command', '(returned nothing)'] unless @_ > 0;
				return undef;
			},
			sub {
				return Future->done(['command', shift]);
			}
		)->on_done(
		sub {
			my ($value) = @_;
			$self->{_check} = $value;
		}
		);
}

## VOLUME

sub check_volume
{
	my ($self, $feature) = @_;

	return $self->_check;
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

				return -1 unless @volumes > 0;
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

## MUTE

sub check_mute
{
	my ($self, $feature) = @_;

	return $self->_check;
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

## MUTE MICROPHONE

sub check_mute_microphone
{
	my ($self, $feature) = @_;

	return $self->_check;
}

sub get_mute_microphone
{
	my ($self, $feature) = @_;
	$self->owner->broadcast($self->config->{command}, 'get-source-mute', '@DEFAULT_SOURCE@')
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

sub set_mute_microphone
{
	my ($self, $feature, $value) = @_;
	$value = $value ? 1 : 0
		unless $value =~ m/toggle/i;

	return $self->owner->broadcast($self->config->{command}, 'set-source-mute', '@DEFAULT_SOURCE@', $value)
		->then(sub { 1 });
}

sub _build_features
{
	my ($self) = @_;

	my $features = $self->SUPER::_build_features;

	$features->{volume}{needs_agent} = !!1;
	$features->{mute}{needs_agent} = !!1;
	$features->{mute_microphone}{needs_agent} = !!1;

	return $features;
}

1;

