package PCRD::Feature;

use v5.14;
use warnings;

use PCRD::Mite;

# https://github.com/tobyink/p5-mite/issues/39
require PCRD::ConfiguredObject;
extends 'PCRD::ConfiguredObject';

has 'name' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'desc' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'info' => (
	is => 'ro',
	isa => 'Str',
);

has 'mode' => (
	is => 'ro',
	isa => 'PCRDFeatureMode',
	coerce => 1,
	required => 1,
);

has 'config_def' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub { {} },
	init_arg => 'config',
);

has 'config' => (
	is => 'ro',
	isa => 'HashRef',
	builder => '_load_config',
	lazy => 1,
	init_arg => undef,
);

has 'vars' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub { {} },
	init_arg => undef,
);

has 'execute_hook' => (
	is => 'ro',
	isa => 'CodeRef',
	predicate => 'has_execute_hook',
);

sub _build_config
{
	my ($self) = @_;
	my $config = $self->SUPER::_build_config;

	$config = $config->clone(
		prefix => [@{$config->prefix}, $self->name]
	);

	return $config;
}

sub _load_config
{
	my ($self) = @_;
	my $config = $self->_config->get_values;

	my $config_def = $self->config_def;
	foreach my $key (keys %{$config_def}) {
		$config->{$key} //= $config_def->{$key}{value};
	}

	return $config;
}

sub enabled
{
	my ($self) = @_;
	my $included_by_default = $self->owner->config->{all_features};

	return !!1 if $included_by_default && !exists $self->config->{enabled};
	return !!$self->config->{enabled};
}

# prepare feature (done first)
sub prepare
{
	my ($self) = @_;
	return if $self->vars->{_prepared};

	my $prepare_method = $self->owner->can("prepare_$self->{name}");
	if ($prepare_method) {
		$self->owner->$prepare_method($self);
	}

	$self->vars->{_prepared} = !!1;
}

# check if feature is functional (done after preparing)
sub check
{
	my ($self) = @_;
	my $check_method = $self->owner->can("check_$self->{name}");

	if ($check_method) {
		return $self->owner->$check_method($self);
	}

	return undef;
}

# init feature for operation (done after checking)
sub init
{
	my ($self) = @_;
	return if $self->vars->{_initialized};

	if ($self->provides('i')) {
		my $init_method = "init_$self->{name}";

		$self->owner->$init_method($self);
	}

	$self->vars->{_initialized} = !!1;
}

# execute feature (done on socket input)
sub execute
{
	my ($self, $action, $arg) = @_;

	state $prefixes = {
		'r' => 'get',
		'w' => 'set',
	};

	die "cannot execute action $action for " . $self->name
		unless $prefixes->{$action};

	my $method = "$prefixes->{$action}_" . $self->name;
	my $result = $self->owner->$method($self, $arg);
	$self->execute_hook->($action, $arg, $result)
		if $self->has_execute_hook;

	return $result;
}

sub provides
{
	my ($self, $action) = @_;

	return !!$self->mode->{$action};
}

sub error_string
{
	my ($self) = @_;

	return join "\n", grep { defined } $self->desc, $self->info;
}

sub dump_config
{
	my ($self) = @_;

	my %current;
	foreach my $key (keys %{$self->config}) {
		my $real_key = join '.', @{$self->_config->prefix}, $key;
		$current{$real_key} = $self->config->{$key} // '';
	}

	my $str = join "\n", map { "$_=$current{$_}" } sort keys %current;
	return $str || '(no config)';
}

1;

