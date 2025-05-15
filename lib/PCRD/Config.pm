package PCRD::Config;

use v5.14;
use warnings;

sub new
{
	my ($class, %args) = @_;
	my $self = bless \%args, $class;
	$self->{prefix} //= [];
	$self->{values} //= {};

	$self->load_config
		unless $self->{no_load};
	return $self;
}

sub dump_config { ... }
sub load_config { ... }

sub clone
{
	my ($self, %args) = @_;
	%args = (%$self, %args);

	return bless \%args, ref $self;
}

sub get_value
{
	my ($self, $name, $default) = @_;

	return $self->get_values->{$name} // $default;
}

sub get_values
{
	my ($self) = @_;

	my $config = $self->{values};
	foreach my $part (@{$self->{prefix}}) {
		$config = $config->{$part};
	}

	return $config;
}

1;

