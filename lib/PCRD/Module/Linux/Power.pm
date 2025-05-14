package PCRD::Module::Linux::Power;

use v5.14;
use warnings;
use List::Util qw(sum min max);
use Scalar::Util qw(looks_like_number);
use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Power';

### CAPACITY

sub prepare_capacity
{
	my ($self, $feature) = @_;

	$feature->{vars}{files} = [glob $feature->{config}{pattern}];
}

sub check_capacity
{
	my ($self, $feature) = @_;

	return @{$feature->{vars}{files}} > 0
		&& PCRD::Util::all { -r } @{$feature->{vars}{files}};
}

sub get_capacity
{
	my ($self, $feature) = @_;

	my $capacity_sum = 0;
	my $capacity_count = 0;
	foreach my $file (@{$feature->{vars}{files}}) {
		$capacity_sum += PCRD::Util::slurp_1($file);
		++$capacity_count;
	}

	# capacity_count always non-zero
	return $capacity_sum / $capacity_count;
}

### CHARGING

sub prepare_charging
{
	my ($self, $feature) = @_;

	$feature->{vars}{files} = [glob $feature->{config}{pattern}];
}

sub check_charging
{
	my ($self, $feature) = @_;

	return @{$feature->{vars}{files}} > 0
		&& PCRD::Util::all { -r } @{$feature->{vars}{files}};
}

sub get_charging
{
	my ($self, $feature) = @_;

	my $any_charging = !!0;
	foreach my $file (@{$feature->{vars}{files}}) {
		my $status = PCRD::Util::slurp_1($file);
		$any_charging = $status !~ /dis|not/i;
		last if $any_charging;
	}

	return $any_charging;
}

### CHARGING THRESHOLD

sub prepare_charging_threshold
{
	my ($self, $feature) = @_;

	$feature->{vars}{start_files} = [glob $feature->{config}{start_pattern}];
	$feature->{vars}{stop_files} = [glob $feature->{config}{stop_pattern}];
}

sub check_charging_threshold
{
	my ($self, $feature) = @_;

	my @start_files = @{$feature->{vars}{start_files}};
	my @stop_files = @{$feature->{vars}{stop_files}};
	return @start_files > 0 && @stop_files > 0 && PCRD::Util::all { -r && -w } @start_files, @stop_files;
}

sub get_charging_threshold
{
	my ($self, $feature) = @_;

	# pcrd doesn't care if the values are all over the place, takes min and max
	my $start_value = min map { PCRD::Util::slurp_1($_) } @{$feature->{vars}{start_files}};
	my $stop_value = max map { PCRD::Util::slurp_1($_) } @{$feature->{vars}{stop_files}};

	return "$start_value-$stop_value";
}

sub set_charging_threshold
{
	my ($self, $feature, $value) = @_;

	my @vals = split /-/, $value;
	die "invalid threshold value format"
		unless (grep { defined && looks_like_number($_) && $_ >= 0 && $_ <= 100 } @vals) == 2;

	foreach my $file (@{$feature->{vars}{start_files}}) {
		PCRD::Util::spew($file, $vals[0]);
	}

	foreach my $file (@{$feature->{vars}{stop_files}}) {
		PCRD::Util::spew($file, $vals[1]);
	}

	return $self->get_charging_threshold($feature);
}

### LIFE

sub prepare_life
{
	my ($self, $feature) = @_;

	$feature->{vars}{files} = [glob $feature->{config}{pattern}];
}

sub check_life
{
	my ($self, $feature) = @_;

	return @{$feature->{vars}{files}} > 0
		&& PCRD::Util::all { -r } @{$feature->{vars}{files}};
}

sub init_life
{
	my ($self, $feature) = @_;

	$feature->{vars}{history} //= [];
	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{pcrd}{probe_interval},
		on_tick => sub {
			unshift @{$feature->{vars}{history}},
				sum map { PCRD::Util::slurp_1($_) } @{$feature->{vars}{files}};
			@{$feature->{vars}{history}} = grep { defined } @{$feature->{vars}{history}}[0 .. 5];
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
}

sub get_life
{
	my ($self, $feature) = @_;

	my $count = @{$feature->{vars}{history}};
	return -1 if $count < 2;

	my $max = $feature->{vars}{history}[-1];
	my $min = $feature->{vars}{history}[0];
	return -1 if $max == $min;

	# actually, $count - 1 intervals have passed, not $count
	my $used = $max - $min;
	my $seconds = $self->{pcrd}{probe_interval} * ($count - 1);

	return int($min / ($used / $seconds) / 60);
}

sub _build_features
{
	my ($self) = @_;

	my $features = $self->SUPER::_build_features;

	$features->{capacity}{info} = 'Battery capacity is usually found in a file located under /sys directory';
	$features->{capacity}{config} = {
		%{$features->{capacity}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/capacity',
		},
	};

	$features->{charging}{info} = 'Battery charging status is usually found in a file located under /sys directory';
	$features->{charging}{config} = {
		%{$features->{charging}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/energy_now',
		},
	};

	$features->{charging_threshold}{info} = 'Charge thresholds are usually found in files located under /sys directory';
	$features->{charging_threshold}{config} = {
		%{$features->{charging_threshold}{config} // {}},
		start_pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/charge_start_threshold',
		},
		stop_pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/charge_stop_threshold',
		},
	};

	$features->{life}{info} = 'Battery life can be calculated a file usually located under /sys directory';
	$features->{life}{config} = {
		%{$features->{life}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/energy_now',
		},
	};

	return $features;
}

1;

