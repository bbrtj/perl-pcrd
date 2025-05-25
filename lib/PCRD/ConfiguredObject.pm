package PCRD::ConfiguredObject;

use v5.14;
use warnings;

use PCRD::Config::File;

use PCRD::Mite;

has 'owner' => (
	is => 'ro',
	isa => "InstanceOf['PCRD::ConfiguredObject']",
	predicate => 'has_owner',
	weak_ref => 1,
);

has 'no_config' => (
	is => 'ro',
	isa => 'Bool',
	default => !!0,
);

has '_config' => (
	is => 'ro',
	isa => "InstanceOf['PCRD::Config']",
	builder => '_build_config',
	lazy => 1,
);

sub _build_config
{
	my ($self) = @_;

	return $self->has_owner
		? $self->owner->_config
		: PCRD::Config::File->new(no_load => $self->no_config)
		;
}

1;

