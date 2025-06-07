package PCRD::Feature;

use v5.14;
use warnings;

use Future;

use PCRD::CheckFailed;

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

has 'needs_agent' => (
	is => 'ro',
	isa => 'Bool',
	default => !!0,
);

has 'functional' => (
	is => 'ro',
	isa => 'Bool',
	writer => '_set_functional',
	default => sub { !!0 },
	init_arg => undef,
);

has 'mode' => (
	is => 'ro',
	isa => 'PCRDFeatureMode',
	coerce => 1,
	required => 1,
);

has 'dependencies' => (
	is => 'ro',
	isa => 'PCRDDependencies',
	coerce => 1,
	default => sub { {} },
);

has 'config_def' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub { {} },
	init_arg => 'config',
	required => 1,
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

has 'execute_hooks' => (
	is => 'ro',
	isa => 'ArrayRef[CodeRef]',
	default => sub { [] },
);

sub _build_config_obj
{
	my ($self) = @_;
	my $config = $self->SUPER::_build_config_obj;

	$config = $config->clone(
		prefix => [@{$config->prefix}, $self->name]
	);

	return $config;
}

sub _load_config
{
	my ($self) = @_;
	my $config = $self->config_obj->get_values;

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

	$self->prepare_dependencies;

	my $prepare_method = $self->owner->can("prepare_$self->{name}");
	if ($prepare_method) {
		$self->owner->$prepare_method($self);
	}

	$self->vars->{_prepared} = !!1;
}

# check if feature is functional (done after preparing)
sub check
{
	my ($self, %args) = @_;
	$self->prepare;

	if ($args{dependencies}) {
		$self->check_dependencies;
		return;
	}

	if (!$self->needs_agent xor $args{agent_present}) {
		my $check_method = $self->owner->can("check_$self->{name}");

		if ($check_method) {
			Future->wrap($self->owner->$check_method($self))
				->retain
				->on_done(
					sub {
						my $res = shift;

						PCRD::CheckFailed->new(
							feature => $self,
							error => $res,
						)->raise_warning if defined $res && !$args{silent};

						$self->_set_functional(!defined $res);
					},
				);
		}
		else {
			$self->_set_functional(!!1);
		}
	}
	elsif ($self->needs_agent) {
		$self->_set_functional(!!0);
	}
}

# init feature for operation (done after checking)
sub init
{
	my ($self, %args) = @_;
	return unless $self->provides('i');
	my $init_method = "init_$self->{name}";

	if (!$self->needs_agent xor $args{agent_present}) {
		$self->owner->$init_method($self, 1);
	}
	elsif ($self->needs_agent) {
		$self->owner->$init_method($self, 0);
	}
}

sub add_execute_hook
{
	my ($self, $hook) = @_;

	push @{$self->execute_hooks}, $hook;
	return;
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

	die 'feature ' . $self->name . ' is not functional'
		unless $self->functional;

	my $method = "$prefixes->{$action}_" . $self->name;
	my $result = $self->owner->$method($self, $arg);

	return scalar Future->wrap($result)->then(
		sub {
			my ($result) = @_;
			foreach my $hook (@{$self->execute_hooks}) {
				$hook->($action, $arg, $result);
			}

			return $result;
		}
	);
}

sub provides
{
	my ($self, $action) = @_;

	return !!$self->mode->{$action};
}

sub dump_config
{
	my ($self) = @_;

	my %current;
	foreach my $key (keys %{$self->config}) {
		my $real_key = join '.', @{$self->config_obj->prefix}, $key;
		$current{$real_key} = $self->config->{$key} // '';
	}

	my $str = join "\n", map { "$_=$current{$_}" } sort keys %current;
	return $str || '(no config)';
}

sub prepare_dependencies
{
	my ($self) = @_;

	my $deps = $self->dependencies;
	foreach my $name (keys %$deps) {
		my ($module, $feature) = split /\./, $name;

		my $ex = PCRD::Util::try {
			$deps->{$name} = $self->owner->owner->module($module)->feature($feature);
		};
	}
}

sub check_dependencies
{
	my ($self) = @_;

	my $deps = $self->dependencies;
	foreach my $name (keys %$deps) {
		my $feat = $deps->{$name};

		# the module will not be functional yet if it needs a connected user agent.
		# assume it will be functional once it does.
		return ['dependency', $name]
			unless $feat && ($feat->functional || $feat->needs_agent);
	}

	return undef;
}

1;

