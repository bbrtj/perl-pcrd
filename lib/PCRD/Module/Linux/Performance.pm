package PCRD::Module::Linux::Performance;

use v5.14;
use warnings;

use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Performance';

### MEMORY

sub check_memory
{
	my ($self, $feature) = @_;

	return -r $feature->{config}{file};
}

sub get_memory
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->{config}{file});

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

sub check_swap
{
	my ($self, $feature) = @_;

	return -r $feature->{config}{file};
}

sub get_swap
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->{config}{file});

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

	return !$ex && @lines > 0;
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

sub check_cpu
{
	my ($self, $feature) = @_;

	return -r $feature->{config}{file};
}

sub get_cpu
{
	my ($self, $feature) = @_;

	my @lines = PCRD::Util::slurp($feature->{config}{file});
	my @cols;
	foreach my $line (@lines) {
		next unless $line =~ /^cpu\b/i;
		@cols = split /\s+/, $line;
		last;
	}

	return ($cols[1] + $cols[2] + $cols[3]) / $cols[4]
		if @cols >= 5;

	die 'could not correctly fetch cpu usage';
}

### CPU SCALING

sub check_cpu_scaling
{
	my ($self, $feature) = @_;

	return -r $feature->{config}{file} && -w $feature->{config}{file};
}

sub get_cpu_scaling
{
	my ($self, $feature) = @_;

	return PCRD::Util::slurp_1($feature->{config}{file});
}

sub set_cpu_scaling
{
	my ($self, $feature, $value) = @_;

	return PCRD::Util::spew($feature->{config}{file}, $value);
}

sub check_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	return !!0 unless $self->feature('cpu_scaling');
	return !!0 unless $self->feature('cpu_scaling')->check;
	return !!0 unless $self->{pcrd}{modules}{Power};
	return !!0 unless $self->{pcrd}{modules}{Power}->feature('status');
	return !!0 unless $self->{pcrd}{modules}{Power}->feature('status')->check;
	return !!1;
}

sub init_cpu_auto_scaling
{
	my ($self, $feature) = @_;

	my $scaling = $self->feature('cpu_scaling');
	my $charging = $self->{pcrd}{modules}{Power}->feature('status');

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{pcrd}{probe_interval},
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
		file => {
			desc => 'file path',
			value => '/proc/meminfo',
		},
	};

	$features->{swap}{info} =
		'Swap memory is found in a file usually located under /proc directory (same as system memory)';
	$features->{swap}{config} = {
		%{$features->{swap}{config} // {}},
		file => {
			desc => 'file path',
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
		file => {
			desc => 'file path',
			value => '/proc/stat',
		},
	};

	$features->{cpu_scaling}{info} = 'CPU scaling is found in a file usually located under /sys directory';
	$features->{cpu_scaling}{config} = {
		%{$features->{cpu_scaling}{config} // {}},
		file => {
			desc => 'file path',
			value => '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor',
		},
	};

	$features->{cpu_auto_scaling}{info} =
		'CPU scaling can be automatically adjusted based on whether the charger is plugged in';
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

