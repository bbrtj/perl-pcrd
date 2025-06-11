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

	return $self->owner->broadcast($feature->config->{command}, '-v')
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
	my ($self, $feature, @output) = @_;

	my $context;
	my $base;
	my %resolution;
	my %active;

	my $max_res = $feature->config->{max_resolution};
	my $compare_res = sub {
		my ($a_x, $a_y) = split /x/, $a;
		my ($b_x, $b_y) = split /x/, $b;

		return $a_x <=> $b_x
			|| $a_y <=> $b_y;
	};

	# assume first item is base
	foreach my $line (@output) {
		if ($line =~ /^(\S+)\s+(dis)?connected\s*(primary)?\s*(\d+x\d+)?/) {
			$context = $1;
			$base //= $context;
			$active{$context} = !!1
				if defined $4;
		}
		elsif ($context && !$resolution{$context} && $line =~ /^\s+(\d+x\d+)/) {
			my $res = $1;

			# assume first listed resolution is the largest
			$resolution{$context} = $max_res ? (sort { $compare_res->() } $res, $max_res)[0] : $res;
		}
	}

	return {
		base => $base,
		resolution => \%resolution,
		active => \%active,
	};
}

sub get_xrandr
{
	my ($self, $feature) = @_;

	return $self->owner->broadcast($feature->config->{command})
		->then(
			sub {
				my $xrandr_data = $self->_xrandr_extract_modes($feature, @_);
				my @result;
				foreach my $output (sort keys %{$xrandr_data->{resolution}}) {
					my $active = $xrandr_data->{active}{$output} ? ' (active)' : '';
					push @result, "$output$active: $xrandr_data->{resolution}{$output}";
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
	my $auto;

	if ($input eq 'auto') {
		$auto = 1;
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

	return $self->owner->broadcast($feature->config->{command})
		->then(
			sub {
				my $xrandr_data = $self->_xrandr_extract_modes($feature, @_);

				# get outputs - active and available
				my $base = $xrandr_data->{base};
				my %active = %{$xrandr_data->{active}};
				my %available = %{$xrandr_data->{resolution}};

				# first output will always be base, then one of the other outputs
				my @outputs = ($base, sort grep { $_ ne $base } keys %active, keys %available);
				splice @outputs, 2;
				my $external = $outputs[1] // '';

				# if there is no external display connected, or base display is
				# not active, simply turn on the base one
				if ($auto && (keys %active == 2 || (keys %active == 1 && !$active{$base}))) {
					$mode = 'O';
				}

				# prepare command tree
				my %command;
				foreach my $flag (split //, $mode) {
					if ($flag eq 'I') {
						die 'side is required for I' unless $side;
						die 'no external display is connected' unless $external;
						push @{$command{$external}}, '--mode', $available{$external}, "--$side", $base;
					}
					elsif ($flag eq 'O') {
						push @{$command{$external}}, '--off'
						if $external;
						push @{$command{$base}}, '--mode', $available{$base}, '--primary';
					}
					elsif ($flag eq 'P') {
						die 'no external display is connected' unless $external;
						push @{$command{$external}}, '--primary';
					}
					elsif ($flag eq 'E') {
						die 'no external display is connected' unless $external;
						push @{$command{$base}}, '--off';
					}
					else {
						die "please specify any of: I, O, P, E";
					}
				}

				# disable any active monitors
				foreach my $out (keys %active) {
					next if $out eq $base;
					next if $out eq $external;
					$command{$out} = ['--off'];
				}

				# prepare and run command
				my @cmd;
				foreach my $out (keys %command) {
					push @cmd, '--output', $out, @{$command{$out}};
				}

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
					value => 8,
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
				max_resolution => {
					desc => 'preferred maximum resolution (AxB, 0 to disable) - must be valid',
					value => 0,
				},
			},
			needs_agent => 1,
		},
	};
}

1;

