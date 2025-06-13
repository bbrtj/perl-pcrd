package PCRD::X;

use v5.14;
use warnings;
use Scalar::Util qw(refaddr);

use PCRD::Mite;

has 'message' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

use overload
	q{""} => 'stringify',
	q{0+} => 'identity',
	fallback => 1,
	;

sub raise
{
	my ($self, $message) = @_;

	$self->new(message => $message)->raise
		unless ref $self;
	die $self;
}

sub stringify
{
	my ($self) = @_;

	return $self->message;
}

sub identity
{
	my ($self) = @_;

	return refaddr $self;
}

1;

