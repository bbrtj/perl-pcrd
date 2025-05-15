package PCRD::ConfiguredObject;

use v5.14;
use warnings;

use PCRD::Config::File;

sub new
{
	my ($class, %args) = @_;

	my $self = bless \%args, $class;
	$self->_load_config;
	return $self;
}

sub _load_config
{
	my ($self, $parent) = @_;
	$parent //= 'pcrd';

	$self->{_config} //= $self->{$parent}{_config}
		// PCRD::Config::File->new(no_load => $self->{no_config});
}

1;

