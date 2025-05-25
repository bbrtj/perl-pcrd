package PCRD::Config;

use v5.14;
use warnings;

use PCRD::Mite;

has 'prefix' => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub { [] },
);

has '_values' => (
	is => 'ro',
	isa => 'HashRef',
	writer => '_set_values',
	default => sub { {} },
	init_arg => 'values',
);

sub dump_config { ... }
sub load_config { ... }

sub explain_config
{
	my ($self, @modules) = @_;
	my @base_prefix = @{$self->prefix};

	my %descs;
	foreach my $module (@modules) {
		my $features = $module->features;
		foreach my $feature (keys %$features) {
			my $feat = $features->{$feature};

			foreach my $config (keys %{$feat->config_def}) {
				my $desc = $feat->config_def->{$config}{desc};
				$descs{join '.', $module->name, $feature, $config}
					= $desc if $desc;
			}
		}
	}

	my $join_key = sub {
		return join '.', grep { defined } @_;
	};

	my $grab_config;
	$grab_config = sub {
		my ($values, @prefix) = @_;

		my @result;
		foreach my $key (keys %$values) {
			if (ref $values->{$key} eq 'HASH') {
				push @result, $grab_config->($values->{$key}, @prefix, $key);
			}
			else {
				push @result, [$join_key->(@prefix, $key), $values->{$key}];
			}
		}

		return @result;
	};

	my @readable_values = $grab_config->($self->get_values, @base_prefix);
	@readable_values = sort { $a->[0] cmp $b->[0] } @readable_values;
	return join "\n", map {
		my $desc = $descs{$_->[0]} ? "# $descs{$_->[0]}\n" : '';
		"$desc$_->[0]=$_->[1]"
	} @readable_values;
}

sub clone
{
	my ($self, %args) = @_;
	%args = (
		prefix => $self->prefix,
		values => $self->_values,
		%args,
	);

	my $class = ref $self;
	return $class->new(%args);
}

sub get_value
{
	my ($self, $name, $default) = @_;

	return $self->get_values->{$name} //= $default;
}

sub get_values
{
	my ($self) = @_;

	my $config = $self->_values;
	foreach my $part (@{$self->prefix}) {
		$config = $config->{$part} //= {};
	}

	return $config;
}

1;

