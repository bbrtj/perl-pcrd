package PCRD::Module::Linux::Performance;

use v5.14;
use warnings;

use List::Util qw(sum);
use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Performance';

### MEMORY

sub prepare_memory
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{files}} = glob $feature->{config}{pattern};
}

sub check_memory
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->{vars}{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->{vars}{files}[0];
	return undef;
}

sub get_memory
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->{vars}{files}[0]);

	my %data;
	foreach my $line (@lines) {
		if ($line =~ /(MemTotal|MemFree|Buffers|Cached):\s+(\d+) \w?B/i) {

			# assume all values are in the same units
			$data{lc $1} = $2;
			last if scalar keys(%data) == 4;
		}
	}

	return ($data{memtotal} - $data{memfree} - $data{buffers} - $data{cached}) / $data{memtotal}
		if scalar keys %data == 4;

	die 'could not correctly fetch memory usage';
}

### SWAP

sub prepare_swap
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{files}} = glob $feature->{config}{pattern};
}

sub check_swap
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->{vars}{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->{vars}{files}[0];
	return undef;
}

sub get_swap
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->{vars}{files}[0]);

	my %data;
	foreach my $line (@lines) {
		if ($line =~ /(SwapTotal|SwapFree):\s+(\d+) \w?B/i) {

			# assume all values are in the same units
			$data{lc $1} = $2;
			last if scalar keys(%data) == 2;
		}
	}

	return 1 - $data{swapfree} / $data{swaptotal}
		if scalar keys %data == 2;

	die 'could not correctly fetch swap usage';
}

### STORAGE

sub check_storage
{
	my ($self, $feature) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($feature->{config}{command});
	};

	return ['command', $ex || '(returned nothing)'] unless !$ex && @lines > 0;
	return undef;
}

sub get_storage
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp_command($feature->{config}{command});
	my @cols;
	foreach my $line (@lines) {
		next unless $line =~ /^total\b/i;
		@cols = split /\s+/, $line;
		last;
	}

	return $cols[2] / $cols[3]
		if @cols >= 4;

	die 'could not correctly fetch storage usage';
}

### CPU

sub prepare_cpu
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{files}} = glob $feature->{config}{pattern};
}

sub check_cpu
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->{vars}{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->{vars}{files}[0];

	my $line = PCRD::Util::slurp_1($feature->{vars}{files}[0]);
	return ['content', $feature->{vars}{files}[0]]
		unless $line =~ /^cpu\b/i && split(/\s+/, $line) >= 5;

	return undef;
}

sub init_cpu
{
	my ($self, $feature) = @_;

	$feature->{vars}{history} //= [];
	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{pcrd}{probe_interval},
		reschedule => 'skip',
		on_tick => sub {
			my $line = PCRD::Util::slurp_1($feature->{vars}{files}[0]);
			my @cols = split /\s+/, $line;

			unshift @{$feature->{vars}{history}}, [$cols[1] + $cols[2] + $cols[3], $cols[4]];
			splice @{$feature->{vars}{history}}, 3;
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
}

sub get_cpu
{
	my ($self, $feature) = @_;

	my @hist = @{$feature->{vars}{history}};
	return -1
		unless @hist > 1;

	my ($base_working, $base_idle) = @{pop @hist};
	my $total_working = 0;
	my $total_idle = 0;
	foreach my $item (@hist) {
		$total_working += $item->[0] - $base_working;
		$total_idle += $item->[1] - $base_idle;
	}

	return $total_working / ($total_working + $total_idle);
}

### CPU SCALING

sub prepare_cpu_scaling
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{files}} = glob $feature->{config}{pattern};
}

sub check_cpu_scaling
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->{vars}{files}} == 1;
	return ['readable', 'pattern'] unless -r $feature->{vars}{files}[0];
	return ['writable', 'pattern'] unless -w $feature->{vars}{files}[0];
	return undef;
}

sub get_cpu_scaling
{
	my ($self, $feature) = @_;

	return PCRD::Util::slurp_1($feature->{vars}{files}[0]);
}

sub set_cpu_scaling
{
	my ($self, $feature, $value) = @_;

	PCRD::Util::spew($feature->{vars}{files}[0], $value);
	return 1;
}

### CPU AUTO SCALING

sub check_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	return
		$self->check_dependency('Performance.cpu_scaling') //
		$self->check_dependency('Power.charging') //
		undef;
}

sub init_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	my $scaling = $self->feature('cpu_scaling');
	my $charging = $self->{pcrd}{modules}{Power}->feature('charging');

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{pcrd}{probe_interval},
		reschedule => 'skip',
		on_tick => sub {
			my $current = $scaling->execute('r');
			my $wanted;

			if ($charging->execute('r')) {
				$wanted = $feature->{config}{ac};
			}
			else {
				$wanted = $feature->{config}{battery};
			}

			$scaling->execute('w', $wanted)
				if $wanted ne $current;
		},
	);

	$timer->start;
	$self->{pcrd}{loop}->add($timer);
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
	};

	$features->{cpu_auto_scaling}{info} =
		'CPU scaling can be automatically adjusted based on whether the charger is plugged in. Requires charging feature from Power module and cpu_scaling feature from this module.';
	$features->{cpu_auto_scaling}{config} = {
		%{$features->{cpu_auto_scaling}{config} // {}},
		ac => {
			desc => 'scaling governor on AC',
			value => 'performance',
		},
		battery => {
			desc => 'scaling governor on battery',
			value => 'powersave',
		},
	};

	return $features;
}

1;

