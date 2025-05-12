package PCRD::Feature;

use v5.14;
use warnings;
use Scalar::Util qw(weaken);

sub new
{
	my ($class, $module, $name, $init_hash) = @_;

	my %args = (
		module => $module,
		name => $name,
		desc => $init_hash->{desc},
		info => $init_hash->{info},
		modes => { map { $_ => 1 } split //, $init_hash->{mode} },
	);

	my $self = bless \%args, $class;
	weaken $self->{module};
	return $self;
}

sub provides
{
	my ($self, $action) = @_;

	return !!$self->{modes}{$action};
}

sub execute
{
	my ($self, $action, $arg) = @_;

	state $prefixes = {
		'r' => 'get',
		'w' => 'set',
	};

	my $method = "$prefixes->{$action}_$self->{name}";
	return $self->{module}->$method($arg);
}

sub check
{
	my ($self) = @_;
	my $check_method = "check_$self->{name}";

	return $self->{module}->$check_method;
}

sub error
{
	my ($self) = @_;

	return join "\n", grep { defined } @{$self}{qw(desc info)};
}

1;

