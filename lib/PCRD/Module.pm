package PCRD::Module;

use v5.14;
use warnings;
use Scalar::Util qw(weaken);

use PCRD::Feature;

use constant name => undef;

sub new
{
	my ($class, %args) = @_;

	$args{daemon} // die 'daemon is required';
	$args{config} //= $args{daemon}{config};

	my $self = bless \%args, $class;
	weaken $self->{daemon};

	return $self;
}

sub init
{
	my ($self) = @_;

	# initialize this module for operation
	...;
}

sub features
{
	my ($self) = @_;

	return $self->{features} //= do {
		my $features = $self->_build_features;

		+{
			map { $_ => PCRD::Feature->new($self, $_, $features->{$_}) }
				keys %$features
		};
	};
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
		my $from_cmd = `uname -s`;
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

