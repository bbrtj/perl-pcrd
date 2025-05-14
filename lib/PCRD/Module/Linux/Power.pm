package PCRD::Module::Linux::Power;

use v5.14;
use warnings;
use List::Util qw(sum min max);
use Scalar::Util qw(looks_like_number);
use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Power';

### CAPACITY

sub check_capacity
{
	my ($self, $feature) = @_;

	my @files = glob $feature->{config}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub init_capacity
{
	my ($self, $feature) = @_;

	$feature->{vars}{files} = [glob $feature->{config}{pattern}];
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

### STATUS

sub check_status
{
	my ($self, $feature) = @_;

	my @files = glob $feature->{config}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub init_status
{
	my ($self, $feature) = @_;

	$feature->{vars}{files} = [glob $feature->{config}{pattern}];
}

sub get_status
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

### BATTERY LIFE

sub check_battery_life
{
	my ($self, $feature) = @_;

	my @files = glob $feature->{config}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub init_battery_life
{
	my ($self, $feature) = @_;

	my @files = glob $feature->{config}{pattern};
	$feature->{vars}{history} //= [];

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{pcrd}{probe_interval},
		on_tick => sub {
			unshift @{$feature->{vars}{history}},
				sum map { PCRD::Util::slurp_1($_) } @files;
			@{$feature->{vars}{history}} = grep { defined } @{$feature->{vars}{history}}[0 .. 5];
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
}

sub get_battery_life
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

### CHARGE THRESHOLD

sub check_charge_threshold
{
	my ($self, $feature) = @_;

	my @start_files = glob $feature->{config}{start_pattern};
	my @stop_files = glob $feature->{config}{stop_pattern};
	return @start_files > 0 && @stop_files > 0 && PCRD::Util::all { -r && -w } @start_files, @stop_files;
}

sub init_charge_threshold
{
	my ($self, $feature) = @_;

	$feature->{vars}{start_files} = [glob $feature->{config}{start_pattern}];
	$feature->{vars}{stop_files} = [glob $feature->{config}{stop_pattern}];
}

sub get_charge_threshold
{
	my ($self, $feature) = @_;

	# pcrd doesn't care if the values are all over the place, takes min and max
	my $start_value = min map { PCRD::Util::slurp_1($_) } @{$feature->{vars}{start_files}};
	my $stop_value = max map { PCRD::Util::slurp_1($_) } @{$feature->{vars}{stop_files}};

	return "$start_value-$stop_value";
}

sub set_charge_threshold
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

	return $self->get_charge_threshold($feature);
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

	$features->{status}{info} = 'Battery status is usually found in a file located under /sys directory';
	$features->{status}{config} = {
		%{$features->{status}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/energy_now',
		},
	};

	$features->{battery_life}{info} = 'Battery life can be calculated a file usually located under /sys directory';
	$features->{battery_life}{config} = {
		%{$features->{battery_life}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/energy_now',
		},
	};

	$features->{charge_threshold}{info} = 'Charge thresholds are usually found in files located under /sys directory';
	$features->{charge_threshold}{config} = {
		%{$features->{charge_threshold}{config} // {}},
		start_pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/charge_start_threshold',
		},
		stop_pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/charge_stop_threshold',
		},
	};

	return $features;
}

1;

