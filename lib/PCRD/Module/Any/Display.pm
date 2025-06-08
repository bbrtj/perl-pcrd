package PCRD::Module::Any::Display;

use v5.14;
use warnings;

use PCRD::Util;

use parent 'PCRD::Module';

use constant name => 'Display';

sub check_brightness { ... }
sub get_brightness { ... }
sub set_brightness { ... }

sub check_xrandr
{
	my ($self, $feature) = @_;

	return $self->owner->broadcast($feature->config->{command})
		->then(
			sub {
				return ['command', '(returned nothing)'] unless @_ > 0;
				return undef;
			},
			sub {
				return Future->done(['command', shift]);
			}
		);
}

sub _xrandr_extract_modes
{
	my ($self, @output) = @_;

	my $context;
	my $base;
	my %modes;
	my %active;

	# assume first item is base
	foreach my $line (@output) {
		if ($line =~ /^(\S+)\s+connected/) {
			$context = $1;
			$base //= $context;
		}
		elsif ($context && $line =~ /^\s+(\d+x\d+)/) {
			my $mode = $1;
			push @{$modes{$context}}, $mode;
			$active{$context} = $mode
				if $line =~ m/\*/;
		}
	}

	return {
		base => $base,
		modes => \%modes,
		active => \%active,
	};
}

sub get_xrandr
{
	my ($self, $feature) = @_;

	return $self->owner->broadcast($feature->config->{command})
		->then(
			sub {
				my $xrandr_data = $self->_xrandr_extract_modes(@_);
				my @result;
				foreach my $output (sort keys %{$xrandr_data->{active}}) {
					push @result, "$output: $xrandr_data->{active}{$output}";
				}

				return join ', ', @result;
			}
		);
}

sub set_xrandr
{
	my ($self, $feature, $input) = @_;

	my $mode;
	my $side;

	if ($input eq 'auto') {
		$mode = $feature->config->{auto_mode};
		$side = $feature->config->{auto_side};
	}
	else {
		($mode, $side) = split /\s+/, $input;
	}

	if ($side) {
		die "invalid side $side"
			unless PCRD::Util::any { $side eq $_ } qw(left right above below);

		$side = "$side-of"
			if PCRD::Util::any { $side eq $_ } qw(left right);
	}

	my %command;
	foreach my $flag (split //, $mode) {
		if ($flag eq 'I') {
			die 'side is required for I' unless $side;
			push @{$command{external}}, '--auto', "--$side", 'BASE';
		}
		elsif ($flag eq 'O') {
			push @{$command{external}}, '--off';
			push @{$command{base}}, '--auto', '--primary';
		}
		elsif ($flag eq 'P') {
			push @{$command{external}}, '--primary';
		}
		elsif ($flag eq 'E') {
			push @{$command{base}}, '--off';
		}
		else {
			die "please specify any of: I, O, P, E";
		}
	}

	return $self->owner->broadcast($feature->config->{command})
		->then(
			sub {
				my $xrandr_data = $self->_xrandr_extract_modes(@_);
				my @modes = sort keys %{$xrandr_data->{modes}};
				@modes = grep { $_ ne $xrandr_data->{base} } @modes;
				@modes = ($xrandr_data->{base}, $modes[0]);

				my @cmd;
				if (@{$command{base}}) {
					push @cmd, '--output', 'BASE', @{$command{base}};
				}

				if (@{$command{external}}) {
					push @cmd, '--output', 'EXTERNAL', @{$command{external}};
				}

				@cmd = map { $_ eq 'BASE' ? $modes[0] : $_ eq 'EXTERNAL' ? $modes[1] : $_ } @cmd;
				return $self->owner->broadcast($feature->config->{command}, @cmd)->then(sub { !!1 });
			}
		);
}

sub _build_features
{
	return {
		brightness => {
			desc => 'Get current display brightness as percent on logarithmic scale',
			mode => 'rw',
			config => {
				step => {
					desc => 'brightness will be increased / decreased by this value',
					value => 10,
				},
			},
		},
		xrandr => {
			desc => 'Handle monitors through xrandr',
			info =>
				'Use capital letters for mode: I for "external on", O for "external off", P for "external primary", E for "external only"',
			mode => 'rw',
			config => {
				command => {
					desc => 'xrandr shell command',
					value => 'xrandr',
				},
				auto_mode => {
					desc => 'preferred auto mode (I, O, P, E)',
					value => 'IP',
				},
				auto_side => {
					desc => 'preferred auto side (left, right, above, below)',
					value => 'left',
				},
			},
			needs_agent => 1,
		},
	};
}

1;

