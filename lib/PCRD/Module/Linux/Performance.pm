package PCRD::Module::Linux::Performance;

use v5.14;
use warnings;

use Future;
use List::Util qw(sum);
use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Any::Performance';

### MEMORY

sub prepare_memory
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
}

sub check_memory
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->vars->{files}[0];
	return undef;
}

sub get_memory
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->vars->{files}[0]);

	my %data;
	foreach my $line (@lines) {
		if ($line =~ /(MemTotal|MemFree|Buffers|Cached):\s+(\d+) \w?B/i) {

			# assume all values are in the same units
			$data{lc $1} = $2;
			last if scalar keys(%data) == 4;
		}
	}

	if (keys %data != 4 || $data{memtotal} == 0) {
		return -1;
	}

	return ($data{memtotal} - $data{memfree} - $data{buffers} - $data{cached}) / $data{memtotal};
}

### SWAP

sub prepare_swap
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
}

sub check_swap
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->vars->{files}[0];
	return undef;
}

sub get_swap
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->vars->{files}[0]);

	my %data;
	foreach my $line (@lines) {
		if ($line =~ /(SwapTotal|SwapFree):\s+(\d+) \w?B/i) {

			# assume all values are in the same units
			$data{lc $1} = $2;
			last if scalar keys(%data) == 2;
		}
	}

	if (keys %data != 2 || $data{swaptotal} == 0) {
		return -1;
	}

	return 1 - $data{swapfree} / $data{swaptotal};
}

### STORAGE

sub check_storage
{
	my ($self, $feature) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($feature->config->{command});
	};

	return ['command', $ex || '(returned nothing)'] unless !$ex && @lines > 0;
	return undef;
}

sub get_storage
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp_command($feature->config->{command});
	my @cols;
	foreach my $line (@lines) {
		next unless $line =~ /^total\b/i;
		@cols = split /\s+/, $line;
		last;
	}

	if (@cols < 4 || $cols[3] == 0) {
		return -1;
	}

	return $cols[2] / $cols[3];
}

### CPU

sub prepare_cpu
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
}

sub check_cpu
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->vars->{files}[0];

	my $line = PCRD::Util::slurp_1($feature->vars->{files}[0]);
	return ['content', $feature->vars->{files}[0]]
		unless $line =~ /^cpu\b/i && split(/\s+/, $line) >= 5;

	return undef;
}

sub init_cpu
{
	my ($self, $feature) = @_;

	$feature->vars->{history} //= [];
	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->owner->probe_interval,
		reschedule => 'skip',
		on_tick => sub {
			my $line = PCRD::Util::slurp_1($feature->vars->{files}[0]);
			my @cols = split /\s+/, $line;

			unshift @{$feature->vars->{history}}, [$cols[1] + $cols[2] + $cols[3], $cols[4]];
			splice @{$feature->vars->{history}}, 3;
		},
	);

	$timer->start;
	$self->owner->notifier->add_child($timer);
}

sub get_cpu
{
	my ($self, $feature) = @_;

	my @hist = @{$feature->vars->{history}};
	return -1
		unless @hist > 1;

	my ($base_working, $base_idle) = @{pop @hist};
	my $total_working = 0;
	my $total_idle = 0;
	foreach my $item (@hist) {
		$total_working += $item->[0] - $base_working;
		$total_idle += $item->[1] - $base_idle;
	}

	my $denominator = ($total_working + $total_idle);
	return -1 if $denominator == 0;
	return $total_working / $denominator;
}

### CPU SCALING

sub prepare_cpu_scaling
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
	@{$feature->vars->{available_files}} = glob $feature->config->{available_pattern};

	# ignore errors at this stage
	PCRD::Util::try {
		@{$feature->vars->{available}} = split /\s+/, PCRD::Util::slurp_1 $feature->vars->{available_files}[0];
	}
}

sub check_cpu_scaling
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->vars->{files}[0];
	return ['writable', 'pattern'] unless -w $feature->vars->{files}[0];

	return ['unique', 'available_pattern'] unless @{$feature->vars->{available_files}} == 1;
	return ['readable', 'available_pattern'] unless -r $feature->vars->{available_files}[0];
	return ['result', 'available_pattern'] unless @{$feature->vars->{available}};

	return undef;
}

sub get_cpu_scaling
{
	my ($self, $feature) = @_;

	return PCRD::Util::slurp_1($feature->vars->{files}[0]);
}

sub set_cpu_scaling
{
	my ($self, $feature, $value) = @_;
	$feature->vars->{validator} //= PCRD::Util::generate_validator(custom => $feature->vars->{available});
	$feature->vars->{validator}->($value);

	PCRD::Util::spew($feature->vars->{files}[0], $value);
	return PCRD::Protocol::TRUE;
}

### CPU AUTO SCALING

sub check_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	my $available = $feature->dependencies->{'Performance.cpu_scaling'}->vars->{available};

	return ['config', 'ac'] unless PCRD::Util::any { $feature->config->{ac} eq $_ } @$available;
	return ['config', 'battery'] unless PCRD::Util::any { $feature->config->{battery} eq $_ } @$available;
	return undef;
}

sub init_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	my $scaling = $feature->dependencies->{'Performance.cpu_scaling'};
	my $ac = $feature->dependencies->{'Power.ac'};

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->owner->probe_interval,
		reschedule => 'skip',
		on_tick => sub {
			my $current = $scaling->execute('r');
			my $is_ac = $ac->execute('r');

			Future->wait_all($current, $is_ac)->on_ready(
				sub {
					my $wanted;

					if ($is_ac->get) {
						$wanted = $feature->config->{ac};
					}
					else {
						$wanted = $feature->config->{battery};
					}

					$scaling->execute('w', $wanted)
						if $wanted ne $current->get;
				}
			);
		},
	);

	$timer->start;
	$self->owner->notifier->add_child($timer);
}

sub _build_features
{
	my ($self) = @_;

	my $features = $self->SUPER::_build_features;

	$features->{memory}{info} = 'System memory is usually found in a file located under /proc directory';
	$features->{memory}{config} = {
		%{$features->{memory}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/proc/meminfo',
		},
	};

	$features->{swap}{info} =
		'Swap memory is found in a file usually located under /proc directory (same as system memory)';
	$features->{swap}{config} = {
		%{$features->{swap}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/proc/meminfo',
		},
	};

	$features->{storage}{info} = 'System storage is calculated by a system command';
	$features->{storage}{config} = {
		%{$features->{storage}{config} // {}},
		command => {
			desc => 'full shell command',
			value => 'df --total',
		},
	};

	$features->{cpu}{info} = 'CPU usage is calculated from data found in a file usually located under /proc diretory';
	$features->{cpu}{config} = {
		%{$features->{cpu}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/proc/stat',
		},
	};

	$features->{cpu_scaling}{info} = 'CPU scaling is found in a file usually located under /sys directory';
	$features->{cpu_scaling}{config} = {
		%{$features->{cpu_scaling}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor',
		},
		available_pattern => {
			desc => 'glob file pattern of the available governors',
			value => '/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors',
		},
	};

	return $features;
}

1;

