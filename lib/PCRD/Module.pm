package PCRD::Module;

use v5.14;
use warnings;

use English;

use PCRD::Feature;

use PCRD::Mite;

extends 'PCRD::ConfiguredObject';

use constant name => undef;

has '+owner' => (
	required => 1,
);

has 'config' => (
	is => 'ro',
	isa => 'HashRef',
	builder => '_load_config',
	lazy => 1,
	init_arg => undef,
);

has 'features' => (
	is => 'ro',
	isa => 'HashRef',
	builder => '_load_features',
	lazy => 1,
	init_arg => undef,
);

sub _build_config
{
	my ($self) = @_;
	my $config = $self->SUPER::_build_config;
	$config = $config->clone(prefix => [$self->name]);

	return $config;
}

sub _load_config
{
	my ($self) = @_;
	my %config = (
		all_features => $self->_config->get_value('all_features', 1),
	);

	return \%config;
}

sub init
{
	my ($self) = @_;

	foreach my $feature (keys %{$self->features}) {
		$self->features->{$feature}->init;
	}
}

sub _load_features
{
	my ($self) = @_;

	my %loaded;
	my $features = $self->_build_features;
	foreach my $key (keys %$features) {
		my $feat = PCRD::Feature->new(
			%{$features->{$key}},
			owner => $self,
			name => $key,
		);
		next unless $feat->enabled;

		$feat->prepare;
		$loaded{$key} = $feat;
	}

	return \%loaded;
}

sub _build_features
{
	# return features provided by this module
	...;
}

sub feature
{
	my ($self, $name) = @_;

	return $self->features->{$name} // die "No such feature: $name";
}

sub check_dependency
{
	my ($self, $name) = @_;
	my ($module, $feature) = split /\./, $name;

	my $ok = !!0;
	my $ex = PCRD::Util::try {
		$ok = !defined $self->owner->module($module)->feature($feature)->check;
	};

	return $ok ? undef : ['dependency', $name];
}

sub check
{
	my ($self) = @_;

	my $module_name = $self->name;
	my $features = $self->features;
	my %check_hash;

	foreach my $feature_name (keys %$features) {
		$check_hash{"$module_name.$feature_name"} = $features->{$feature_name};
	}

	return \%check_hash;
}

sub load_plugin
{
	my ($class, $plugin_file) = @_;

	# expand ~ shortcut
	$plugin_file =~ s/^~/$ENV{HOME}/;

	do $plugin_file
		or die "could not load plugin $plugin_file: " . ($@ || $!);
}

sub get_implementation
{
	my ($class, $name, $error_ref) = @_;
	state $kernel = ucfirst $OSNAME;

	$$error_ref = ''
		if $error_ref;

	$name //= $class->name;
	foreach my $impl ($kernel, 'Any') {
		my $module_name = "PCRD::Module::${impl}::${name}";

		local $@;
		my $loaded = eval "$module_name->name; 1;" || eval "require $module_name; 1";
		$$error_ref .= $@ if !$loaded && $error_ref;
		return $module_name if $loaded;
	}

	return undef;
}

1;

