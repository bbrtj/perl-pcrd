package PCRD::Listener;

use v5.14;
use warnings;

use Future;
use Scalar::Util qw(weaken);

use PCRD::Stream;

use PCRD::Mite;
extends 'PCRD::ConfiguredObject';

has '_listener' => (
	is => 'ro',
	isa => "InstanceOf ['IO::Async::Listener']",
	builder => '_build_listener',
	lazy => 1,
	init_arg => undef,
);

has 'streams' => (
	is => 'ro',
	isa => "ArrayRef [InstanceOf ['PCRD::Stream']]",
	default => sub { [] },
);

has 'user_agent' => (
	is => 'ro',
	isa => "Maybe [InstanceOf ['PCRD::Stream']]",
	writer => 'set_user_agent',
	default => undef,
);

has 'agent_handlers' => (
	is => 'ro',
	isa => "HashRef [InstanceOf ['Future']]",
	default => sub { {} },
	init_arg => undef,
);

has '_last_id' => (
	is => 'rw',
	default => sub { 0 },
	init_arg => undef,
);

with qw(PCRD::Role::HasOwner);

has '+owner' => (
	isa => "InstanceOf ['PCRD']",
	required => 1,
);

sub BUILD
{
	my ($self) = @_;

	$self->_listener;
}

sub _build_listener
{
	my ($self) = @_;
	weaken $self;

	my $listener = IO::Async::Listener->new(
		on_stream => sub {
			my (undef, $raw_stream) = @_;

			push @{$self->streams}, PCRD::Stream->new(
				owner => $self,
				stream => $raw_stream,
			);

			$self->owner->notifier->add_child($raw_stream);
		}
	);

	# listener does not work as a notifier child
	$self->owner->notifier->on_loop(
		sub {
			my $loop = shift;

			$loop->add($listener);
			$listener->listen(
				handle => $self->owner->socket,
			);
		}
	);

	return $listener;
}

sub _next_id
{
	my ($self) = @_;
	my $last = $self->_last_id;
	$self->_last_id(++$last);
	return $last;
}

sub register_user_agent
{
	my ($self, $ua) = @_;

	die 'user agent already registered'
		if defined $self->user_agent;

	$self->set_user_agent($ua);
}

sub unregister_stream
{
	my ($self, $stream) = @_;

	@{$self->streams} = grep { $_ != $stream } @{$self->streams};
	$self->set_user_agent(undef)
		if defined $self->user_agent && $stream == $self->user_agent;

	return;
}

sub send_to_agent
{
	my ($self, @parts) = @_;

	if (!defined $self->user_agent) {
		return Future->fail('user agent is not present');
	}

	my $id = $self->_next_id;
	my $future = $self->agent_handlers->{$id} = Future->new;
	$self->user_agent->send($id, @parts);

	return $future;
}

1;

