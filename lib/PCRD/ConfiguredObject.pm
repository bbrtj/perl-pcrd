package PCRD::ConfiguredObject;

use v5.14;
use warnings;

use PCRD::Config::File;

use PCRD::Mite;

has 'load_config' => (
	is => 'ro',
	isa => 'Bool',
	default => !!1,
);

has 'config_obj' => (
	is => 'ro',
	isa => "InstanceOf['PCRD::Config']",
	builder => '_build_config_obj',
	lazy => 1,
);

with qw(PCRD::Role::HasOwner);

sub _build_config_obj
{
	my ($self) = @_;

	my $obj;
	if ($self->has_owner) {
		$obj = $self->owner->config_obj;
	}
	else {
		$obj = PCRD::Config::File->new;
		$obj->load_config
			if $self->load_config;
	}

	return $obj;
}

1;

