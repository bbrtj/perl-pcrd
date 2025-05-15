package PCRD::Feature;

use v5.14;
use warnings;
use Scalar::Util qw(weaken);

use parent 'PCRD::ConfiguredObject';

sub new
{
	my ($class, $module, $name, $init_hash) = @_;
	my %args = (
		module => $module,
		name => $name,
		desc => $init_hash->{desc},
		info => $init_hash->{info},
		modes => {map { $_ => 1 } split //, $init_hash->{mode}},
		config_def => $init_hash->{config} // {},
		config => {},
		vars => {},
	);

	my $self = $class->SUPER::new(%args);
	weaken $self->{module};

	return $self;
}

sub _load_config
{
	my ($self) = @_;
	$self->SUPER::_load_config('module');

	$self->{_config} = $self->{_config}->clone(
		prefix => [@{$self->{module}{_config}{prefix}}, $self->{name}]
	);

	$self->{config} = $self->{_config}->get_values;

	foreach my $key (keys %{$self->{config_def}}) {
		$self->{config}{$key} //= $self->{config_def}{$key}{value};
	}
}

sub enabled
{
	my ($self) = @_;
	my $included_by_default = $self->{module}{config}{all_features};

	return !!1 if $included_by_default && !exists $self->{config}{enabled};
	return !!$self->{config}{enabled};
}

# prepare feature (done first)
sub prepare
{
	my ($self) = @_;
	return if $self->{prepared};

	my $prepare_method = $self->{module}->can("prepare_$self->{name}");
	if ($prepare_method) {
		$self->{module}->$prepare_method($self);
	}

	$self->{prepared} = !!1;
}

# check if feature is functional (done after preparing)
sub check
{
	my ($self) = @_;
	my $check_method = $self->{module}->can("check_$self->{name}");

	if ($check_method) {
		return $self->{module}->$check_method($self);
	}

	return undef;
}

# init feature for operation (done after checking)
sub init
{
	my ($self) = @_;
	return if $self->{initialized};

	if ($self->provides('i')) {
		my $init_method = "init_$self->{name}";

		$self->{module}->$init_method($self);
	}

	$self->{initialized} = !!1;
}

# execute feature (done on socket input)
sub execute
{
	my ($self, $action, $arg) = @_;

	state $prefixes = {
		'r' => 'get',
		'w' => 'set',
	};

	die "cannot execute action $action for $self->{name}"
		unless $prefixes->{$action};

	my $method = "$prefixes->{$action}_$self->{name}";
	return $self->{module}->$method($self, $arg);
}

sub provides
{
	my ($self, $action) = @_;

	return !!$self->{modes}{$action};
}

sub error_string
{
	my ($self) = @_;

	return join "\n", grep { defined } @{$self}{qw(desc info)};
}

sub dump_config
{
	my ($self) = @_;

	my %current;
	foreach my $key (keys %{$self->{config}}) {
		my $real_key = join '.', @{$self->{_config}{prefix}}, $key;
		$current{$real_key} = $self->{config}{$key} // '';
	}

	my $str = join "\n", map { "$_=$current{$_}" } sort keys %current;
	return $str || '(no config)';
}

1;

