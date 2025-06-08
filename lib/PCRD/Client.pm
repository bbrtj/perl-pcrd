package PCRD::Client;

use v5.14;
use warnings;

use IO::Socket::UNIX;
use IO::Async::Stream;

use PCRD::Mite;
use PCRD::Protocol;

extends 'PCRD::ConfiguredObject';

has 'socket_config' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {
		my $hash = shift->config_obj->get_value('socket', {});
		$hash->{file} //= '/var/run/pcrd.sock';

		return $hash;
	},
	lazy => 1,
	init_arg => undef,
);

has 'on_message' => (
	is => 'ro',
	isa => 'CodeRef',
	required => 1,
);

has 'stream' => (
	is => 'ro',
	isa => "InstanceOf['IO::Async::Stream']",
	builder => '_build_stream',
	lazy => 1,
	init_arg => undef,
);

sub _build_stream
{
	my ($self) = @_;

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Peer => $self->socket_config->{file},
	) or die "Cannot create socket stream - $IO::Socket::errstr";

	return IO::Async::Stream->new(
		handle => $socket,
		on_read => $self->_message_handler,
		on_closed => sub { die 'daemon disconnected' },
	);
}

sub _message_handler
{
	my ($self) = @_;
	my $on_message = $self->on_message;

	return sub {
		my ($stream, $buffref, $eof) = @_;

		while (my @parts = PCRD::Protocol::extract_message($buffref)) {
			$on_message->(@parts);
		}

		return 0;
	};
}

sub send
{
	my ($self, @parts) = @_;

	$self->stream->write(PCRD::Protocol::message(grep { defined } @parts));
}

sub start
{
	my ($self, $loop_or_notifier) = @_;

	if ($loop_or_notifier->isa('IO::Async::Loop')) {
		$loop_or_notifier->add($self->stream);
	}
	elsif ($loop_or_notifier->isa('IO::Async::Notifier')) {
		$loop_or_notifier->add_child($self->stream);
	}
	else {
		die 'Cannot start client - neither loop or notifier passed';
	}
}

1;

