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

	$feature->vars->{files} = [glob $feature->config->{pattern}];
}

sub check_capacity
{
	my ($self, $feature) = @_;

	return ['found', 'pattern'] unless @{$feature->vars->{files}} > 0;
	return ['readable', 'pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{files}};
	return undef;
}

sub get_capacity
{
	my ($self, $feature) = @_;

	my $capacity_sum = 0;
	my $capacity_count = 0;
	foreach my $file (@{$feature->vars->{files}}) {
		$capacity_sum += PCRD::Util::slurp_1($file);
		++$capacity_count;
	}

	# capacity_count always non-zero
	return $capacity_sum / $capacity_count;
}

### AC

sub prepare_ac
{
	my ($self, $feature) = @_;

	$feature->vars->{files} = [glob $feature->config->{pattern}];
}

sub check_ac
{
	my ($self, $feature) = @_;

	return ['found', 'pattern'] unless @{$feature->vars->{files}} > 0;
	return ['readable', 'pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{files}};
	return undef;
}

sub get_ac
{
	my ($self, $feature) = @_;

	my $any_ac = !!0;
	foreach my $file (@{$feature->vars->{files}}) {
		my $status = PCRD::Util::slurp_1($file);
		$any_ac = $status eq '1';
		last if $any_ac;
	}

	return $any_ac;
}

### CHARGING

sub prepare_charging
{
	my ($self, $feature) = @_;

	$feature->vars->{files} = [glob $feature->config->{pattern}];
}

sub check_charging
{
	my ($self, $feature) = @_;

	return ['found', 'pattern'] unless @{$feature->vars->{files}} > 0;
	return ['readable', 'pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{files}};
	return undef;
}

sub get_charging
{
	my ($self, $feature) = @_;

	my $any_charging = !!0;
	foreach my $file (@{$feature->vars->{files}}) {
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

	$feature->vars->{start_files} = [glob $feature->config->{start_pattern}];
	$feature->vars->{stop_files} = [glob $feature->config->{stop_pattern}];
}

sub check_charging_threshold
{
	my ($self, $feature) = @_;

	return ['found', 'start_pattern'] unless @{$feature->vars->{start_files}} > 0;
	return ['readable', 'start_pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{start_files}};
	return ['writable', 'start_pattern'] unless PCRD::Util::all { -w } @{$feature->vars->{start_files}};
	return ['found', 'stop_pattern'] unless @{$feature->vars->{stop_files}} > 0;
	return ['readable', 'stop_pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{stop_files}};
	return ['writable', 'stop_pattern'] unless PCRD::Util::all { -w } @{$feature->vars->{stop_files}};
	return undef;
}

sub get_charging_threshold
{
	my ($self, $feature) = @_;

	# pcrd doesn't care if the values are all over the place, takes min and max
	my $start_value = min map { PCRD::Util::slurp_1($_) } @{$feature->vars->{start_files}};
	my $stop_value = max map { PCRD::Util::slurp_1($_) } @{$feature->vars->{stop_files}};

	return "$start_value-$stop_value";
}

sub set_charging_threshold
{
	my ($self, $feature, $value) = @_;

	my @vals = split /-/, $value;
	die "invalid threshold value format"
		unless (grep { defined && looks_like_number($_) && $_ >= 0 && $_ <= 100 } @vals) == 2;

	foreach my $file (@{$feature->vars->{start_files}}) {
		PCRD::Util::spew($file, $vals[0]);
	}

	foreach my $file (@{$feature->vars->{stop_files}}) {
		PCRD::Util::spew($file, $vals[1]);
	}

	return 1;
}

### LIFE

sub prepare_life
{
	my ($self, $feature) = @_;

	$feature->vars->{files} = [glob $feature->config->{pattern}];
	$feature->vars->{history_size} = int($feature->config->{measurement_window} * 60 / $self->owner->probe_interval);
}

sub check_life
{
	my ($self, $feature) = @_;

	return ['found', 'pattern'] unless @{$feature->vars->{files}} > 0;
	return ['readable', 'pattern'] unless PCRD::Util::all { -r } @{$feature->vars->{files}};
	return undef;
}

sub init_life
{
	my ($self, $feature) = @_;

	$feature->vars->{history} //= [];
	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->owner->probe_interval,
		reschedule => 'skip',
		on_tick => sub {
			unshift @{$feature->vars->{history}},
				sum map { PCRD::Util::slurp_1($_) } @{$feature->vars->{files}};
			splice @{$feature->vars->{history}}, $feature->vars->{history_size};
		},
	);

	$timer->start;
	$self->owner->notifier->add_child($timer);
}

sub get_life
{
	my ($self, $feature) = @_;

	my $count = @{$feature->vars->{history}};
	return -1 if $count < 2;

	my $max = $feature->vars->{history}[-1];
	my $min = $feature->vars->{history}[0];
	return -1 if $max <= $min;

	# actually, $count - 1 intervals have passed, not $count
	my $used = $max - $min;
	my $seconds = $self->owner->probe_interval * ($count - 1);

	return int($min / ($used / $seconds) / 60);
}

## SUSPEND

sub prepare_suspend
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
}

sub check_suspend
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['writable', 'pattern'] unless -w $feature->vars->{files}[0];
	return undef;
}

sub set_suspend
{
	my ($self, $feature, $value) = @_;

	PCRD::Util::spew($feature->vars->{files}[0], $feature->config->{state});
	return 1;
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

	$features->{ac}{info} = 'AC status is usually found in a file located under /sys directory';
	$features->{ac}{config} = {
		%{$features->{ac}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/AC*/online',
		},
	};

	$features->{charging}{info} = 'Battery charging status is usually found in a file located under /sys directory';
	$features->{charging}{config} = {
		%{$features->{charging}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/class/power_supply/BAT*/status',
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

	$features->{suspend}{info} = 'Suspend is done by writing to a file usually found under /sys directory';
	$features->{suspend}{config} = {
		%{$features->{suspend}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/power/state',
		},
		state => {
			desc => 'state to which the machine should be put',
			value => 'mem',
		},
	};

	return $features;
}

1;

