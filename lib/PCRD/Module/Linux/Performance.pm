package PCRD::Module::Linux::Performance;

use v5.14;
use warnings;

use IO::Async::Timer::Periodic;

use parent 'PCRD::Module::Performance';

use constant MEMORY_CONFIG => ['Performance.memory.file', '/proc/meminfo'];
use constant STORAGE_CONFIG => ['Performance.storage.command', 'df --total'];
use constant CPU_CONFIG => ['Performance.cpu.file', '/proc/stat'];
use constant CPU_SCALING_CONFIG =>
	['Performance.cpu_scaling.file', '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'];
use constant CPU_SCALING_AUTO_CONFIG => ['Performance.cpu_scaling.auto.enabled', '1'];
use constant CPU_SCALING_AUTO_AC_CONFIG => ['Performance.cpu_scaling.auto.ac', 'performance'];
use constant CPU_SCALING_AUTO_BAT_CONFIG => ['Performance.cpu_scaling.auto.bat', 'powersave'];
use constant PROBE_INTERVAL_CONFIG => ['probe_interval', 10];

sub new
{
	my ($class, %args) = @_;
	my $self = $class->SUPER::new(%args);
	my $c = $self->{config};

	$self->{probe_interval} = $c->get_value(@{(PROBE_INTERVAL_CONFIG)});
	$self->{memory}{file} = $c->get_value(@{(MEMORY_CONFIG)});
	$self->{storage}{command} = $c->get_value(@{(STORAGE_CONFIG)});
	$self->{cpu}{file} = $c->get_value(@{(CPU_CONFIG)});
	$self->{cpu_scaling}{file} = $c->get_value(@{(CPU_SCALING_CONFIG)});
	$self->{cpu_scaling}{auto}{enabled} = $c->get_value(@{(CPU_SCALING_AUTO_CONFIG)});
	$self->{cpu_scaling}{auto}{ac} = $c->get_value(@{(CPU_SCALING_AUTO_AC_CONFIG)});
	$self->{cpu_scaling}{auto}{bat} = $c->get_value(@{(CPU_SCALING_AUTO_BAT_CONFIG)});

	return $self;
}

sub init
{
	my ($self) = @_;

	$self->setup_cpu_scaling;
}

### MEMORY

sub check_memory
{
	my ($self) = @_;

	return -r $self->{memory}{file};
}

sub get_memory
{
	my ($self) = @_;

	my @lines = PCRD::Util::slurp($self->{memory}{file});

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
	my ($self) = @_;

	return $self->check_memory;
}

sub get_swap
{
	my ($self) = @_;

	my @lines = PCRD::Util::slurp($self->{memory}{file});

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
	my ($self) = @_;

	my @lines;
	my $ex = PCRD::Util::try {
		@lines = PCRD::Util::slurp_command($self->{storage}{command});
	};

	return !$ex && @lines > 0;
}

sub get_storage
{
	my ($self) = @_;

	my @lines = PCRD::Util::slurp_command($self->{storage}{command});
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
	my ($self) = @_;

	return -r $self->{cpu}{file};
}

sub get_cpu
{
	my ($self) = @_;

	my @lines = PCRD::Util::slurp($self->{cpu}{file});
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
	my ($self) = @_;

	return !!0 unless -r $self->{cpu_scaling}{file} && -w $self->{cpu_scaling}{file};

	# dependency on Power module
	if ($self->{cpu_scaling}{auto}{enabled}) {
		return !!0 unless $self->{daemon}{modules}{Power};
	}

	return !!1;
}

sub setup_cpu_scaling
{
	my ($self) = @_;
	return unless $self->{cpu_scaling}{auto}{enabled};

	my $timer = IO::Async::Timer::Periodic->new(
		interval => $self->{probe_interval},
		on_tick => sub {
			my $current = $self->get_cpu_scaling;
			my $wanted;

			if ($self->{daemon}{modules}{Power}->get_status) {
				$wanted = $self->{cpu_scaling}{auto}{ac};
			}
			else {
				$wanted = $self->{cpu_scaling}{auto}{bat};
			}

			$self->set_cpu_scaling($wanted)
				if $wanted ne $current;
		},
	);

	$timer->start;
	$self->{daemon}{loop}->add($timer);
}

sub get_cpu_scaling
{
	my ($self) = @_;

	return PCRD::Util::slurp_1($self->{cpu_scaling}{file});
}

sub set_cpu_scaling
{
	my ($self, $value) = @_;

	return PCRD::Util::spew($self->{cpu_scaling}{file}, $value);
}

sub _build_features
{
	my ($self) = @_;

	my $features = $self->SUPER::_build_features;

	$features->{memory}{info} = <<"	INFO";
	System memory is found in a file located under /proc directory.
	Currently, pcrd gets it from $self->{memory}{file}. It may be
	modified by changing '@{[MEMORY_CONFIG->[0]]}' configuration value.
	INFO

	$features->{swap}{info} = <<"	INFO";
	Swap memory is found in a file located under /proc directory (same as
	system memory). Currently, pcrd gets it from $self->{memory}{file}.
	It may be modified by changing '@{[MEMORY_CONFIG->[0]]}' configuration
	value.
	INFO

	$features->{storage}{info} = <<"	INFO";
	System storage is calculated by a system command. Currently, pcrd runs
	'$self->{storage}{command}'. It may be modified by changing
	'@{[STORAGE_CONFIG->[0]]}' configuration value.
	INFO

	$features->{cpu}{info} = <<"	INFO";
	CPU usage is calculated from data found in a file located under /proc
	diretory. Currently, pcrd calculates it based on contents of
	$self->{cpu}{file}. It may be modified by changing
	'@{[CPU_CONFIG->[0]]}' configuration value.
	INFO

	$features->{cpu_scaling}{info} = <<"	INFO";
	CPU scaling is found in a file located under /sys directory. Currently,
	pcrd gets it from $self->{cpu_scaling}{file}. It may be modified by
	changing '@{[CPU_SCALING_CONFIG->[0]]}' configuration value.
	INFO

	return $features;
}

1;

