package PCRD::Config;

use v5.14;
use warnings;

sub instance
{
	my ($class, %args) = @_;
	my $name = delete $args{name} // 'default';

	state $singletons = {};
	return $singletons->{$name} //= do {
		my $self = bless \%args, $class;

		$self->load_config;
		$self;
	};
}

sub load_config
{
	my ($self) = @_;

	...;
}

sub get_value
{
	my ($self, $name, $default) = @_;

	return $self->{values}{$name} // $default;
}

1;

