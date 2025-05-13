package PCRD::Module::Linux::Power;

use v5.14;
use warnings;
use List::Util qw(sum min max);
use Scalar::Util qw(looks_like_number);
use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Power';

use constant CAPACITY_CONFIG => ['Power.capacity.pattern', '/sys/class/power_supply/BAT*/capacity'];
use constant STATUS_CONFIG => ['Power.status.pattern', '/sys/class/power_supply/BAT*/status'];
use constant BATTERY_LIFE_CONFIG => ['Power.battery_life.pattern', '/sys/class/power_supply/BAT*/energy_now'];
use constant BATTERY_LIFE_PROBE_INTERVAL_CONFIG => ['Power.battery_life.probe_interval', 10];
use constant CHARGE_START_THRESHOLD_CONFIG =>
	['Power.charge_threshold.start_pattern', '/sys/class/power_supply/BAT*/charge_start_threshold'];
use constant CHARGE_STOP_THRESHOLD_CONFIG =>
	['Power.charge_threshold.stop_pattern', '/sys/class/power_supply/BAT*/charge_stop_threshold'];

sub new
{
	my ($class, %args) = @_;
	my $self = $class->SUPER::new(%args);
	my $c = $self->{config};

	$self->{capacity}{pattern} = $c->get_value(@{(CAPACITY_CONFIG)});
	$self->{status}{pattern} = $c->get_value(@{(STATUS_CONFIG)});
	$self->{battery_life}{pattern} = $c->get_value(@{(BATTERY_LIFE_CONFIG)});
	$self->{battery_life}{probe_interval} = $c->get_value(@{(BATTERY_LIFE_PROBE_INTERVAL_CONFIG)});
	$self->{charge_threshold}{start_pattern} = $c->get_value(@{(CHARGE_START_THRESHOLD_CONFIG)});
	$self->{charge_threshold}{stop_pattern} = $c->get_value(@{(CHARGE_STOP_THRESHOLD_CONFIG)});

	return $self;
}

sub init
{
	my ($self) = @_;

	$self->setup_capacity;
	$self->setup_status;
	$self->setup_battery_life;
	$self->setup_charge_threshold;
}

### CAPACITY

sub check_capacity
{
	my ($self) = @_;

	my @files = glob $self->{capacity}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub setup_capacity
{
	my ($self) = @_;

	$self->{capacity}{file_cache} = [glob $self->{capacity}{pattern}];
}

sub get_capacity
{
	my ($self) = @_;

	my $capacity_sum = 0;
	my $capacity_count = 0;
	foreach my $file (@{$self->{capacity}{file_cache}}) {
		$capacity_sum += PCRD::Util::slurp_1($file);
		++$capacity_count;
	}

	# capacity_count always non-zero
	return $capacity_sum / $capacity_count;
}

### STATUS

sub check_status
{
	my ($self) = @_;

	my @files = glob $self->{status}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub setup_status
{
	my ($self) = @_;

	$self->{status}{file_cache} = [glob $self->{status}{pattern}];
}

sub get_status
{
	my ($self) = @_;

	my $any_charging = !!0;
	foreach my $file (@{$self->{status}{file_cache}}) {
		my $status = PCRD::Util::slurp_1($file);
		$any_charging = $status !~ /dis|not/i;
		last if $any_charging;
	}

	return $any_charging;
}

### BATTERY LIFE

sub check_battery_life
{
	my ($self) = @_;

	my @files = glob $self->{battery_life}{pattern};
	return @files > 0 && PCRD::Util::all { -r } @files;
}

sub setup_battery_life
{
	my ($self) = @_;

	my @files = glob $self->{battery_life}{pattern};
	$self->{battery_life}{history} //= [];

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{battery_life}{probe_interval},
		on_tick => sub {
			unshift @{$self->{battery_life}{history}},
				sum map { PCRD::Util::slurp_1($_) } @files;
			@{$self->{battery_life}{history}} = grep { defined } @{$self->{battery_life}{history}}[0 .. 5];
		},
	);

	$timer->start;
	$self->{daemon}{loop}->add($timer);
}

sub get_battery_life
{
	my ($self) = @_;

	my $count = @{$self->{battery_life}{history}};
	return -1 if $count < 2;

	my $max = $self->{battery_life}{history}[-1];
	my $min = $self->{battery_life}{history}[0];
	return -1 if $max == $min;

	my $used = $max - $min;
	my $seconds = $self->{battery_life}{probe_interval} * $count;

	return int($min / ($used / $seconds) / 60);
}

### CHARGE THRESHOLD

sub check_charge_threshold
{
	my ($self) = @_;

	my @start_files = glob $self->{charge_threshold}{start_pattern};
	my @stop_files = glob $self->{charge_threshold}{stop_pattern};
	return @start_files > 0 && @stop_files > 0 && PCRD::Util::all { -r && -w } @start_files, @stop_files;
}

sub setup_charge_threshold
{
	my ($self) = @_;

	$self->{charge_threshold}{start_file_cache} = [glob $self->{charge_threshold}{start_pattern}];
	$self->{charge_threshold}{stop_file_cache} = [glob $self->{charge_threshold}{stop_pattern}];
}

sub get_charge_threshold
{
	my ($self) = @_;

	# pcrd doesn't care if the values are all over the place, takes min and max
	my $start_value = min map { PCRD::Util::slurp_1($_) } @{$self->{charge_threshold}{start_file_cache}};
	my $stop_value = max map { PCRD::Util::slurp_1($_) } @{$self->{charge_threshold}{stop_file_cache}};

	return "$start_value-$stop_value";
}

sub set_charge_threshold
{
	my ($self, $value) = @_;

	my @vals = split /-/, $value;
	die "invalid threshold value format"
		unless (grep { defined && looks_like_number($_) && $_ >= 0 && $_ <= 100 } @vals) == 2;

	foreach my $file (@{$self->{charge_threshold}{start_file_cache}}) {
		PCRD::Util::spew($file, $vals[0]);
	}

	foreach my $file (@{$self->{charge_threshold}{stop_file_cache}}) {
		PCRD::Util::spew($file, $vals[1]);
	}

	return $self->get_charge_threshold;
}

sub _build_features
{
	my ($self) = @_;

	my $features = $self->SUPER::_build_features;

	$features->{capacity}{info} = <<"	INFO";
	Battery capacity is found in a file located under /sys directory.
	Currently, pcrd searches for it in $self->{capacity}{pattern}. It may be
	modified by changing '@{[CAPACITY_CONFIG->[0]]}' configuration value.
	INFO

	$features->{status}{info} = <<"	INFO";
	Battery status is found in a file located under /sys directory.
	Currently, pcrd searches for it in $self->{status}{pattern}. It may be
	modified by changing '@{[STATUS_CONFIG->[0]]}' configuration value.
	INFO

	$features->{battery_life}{info} = <<"	INFO";
	Battery life can be calculated a file located under /sys directory.
	Currently, pcrd searches for it in $self->{battery_life}{pattern}. It may be
	modified by changing '@{[BATTERY_LIFE_CONFIG->[0]]}' configuration value.
	INFO

	$features->{charge_threshold}{info} = <<"	INFO";
	Charge thresholds are found in files located under /sys directory.
	Currently, pcrd searches for them in $self->{charge_threshold}{start_pattern}
	and $self->{charge_threshold}{stop_pattern}. They may be modified by changing
	'@{[CHARGE_START_THRESHOLD_CONFIG->[0]]}' and '@{[CHARGE_STOP_THRESHOLD_CONFIG->[0]]}'
	configuration values, respectively.
	INFO

	return $features;
}

1;

