package PCRD::Module;

use v5.14;
use warnings;
use Scalar::Util qw(weaken);

use PCRD::Feature;

use constant name => undef;

sub new
{
	my ($class, %args) = @_;

	$args{pcrd} // die 'pcrd is required';

	my $self = bless \%args, $class;
	weaken $self->{pcrd};

	$self->_load_config;
	return $self;
}

sub _load_config
{
	my ($self) = @_;

	$self->{_config} //= $self->{pcrd}{_config}->clone(prefix => [$self->name]);
	$self->{config}{all_features} = $self->{_config}->get_value('all_features', 1);
}

sub init
{
	my ($self) = @_;

	foreach my $feature (keys %{$self->features}) {
		$self->features->{$feature}->init;
	}
}

sub features
{
	my ($self) = @_;

	return $self->{features}
		if defined $self->{features};

	my $features = $self->_build_features;
	foreach my $key (keys %$features) {
		my $feat = PCRD::Feature->new($self, $key, $features->{$key});
		next unless $feat->enabled;

		$self->{features}{$key} = $feat;
	}

	return $self->{features} // {};
}

sub _build_features
{
	# return features provided by this module
	...;
}

sub feature
{
	my ($self, $name) = @_;

	return $self->features->{$name};
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

sub get_implementation
{
	my ($class, $name, $error_ref) = @_;
	state $kernel = do {
		my ($from_cmd) = PCRD::Util::slurp_command('uname', '-s');
		chomp $from_cmd;
		$from_cmd;
	};

	$name //= $class->name;
	my $module_name = "PCRD::Module::${kernel}::${name}";

	local $@;
	my $loaded = eval "require $module_name; 1";
	$$error_ref = $@ if !$loaded && $error_ref;

	return $loaded ? $module_name : undef;
}

1;

