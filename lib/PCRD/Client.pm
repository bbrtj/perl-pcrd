package PCRD::Client;

use v5.14;
use warnings;

use IO::Socket::UNIX;
use IO::Async::Stream;

use parent 'PCRD::ConfiguredObject';

sub _load_config
{
	my ($self) = @_;
	$self->SUPER::_load_config;

	$self->{socket} = $self->{_config}->get_value('socket', {});
	$self->{socket}{file} //= '/tmp/pcrd.sock';
}

sub setup
{
	my ($self, $on_message) = @_;

	die "could not connect to socket $self->{socket}{file} - server not running?"
		unless -e $self->{socket}{file};

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Peer => $self->{socket}{file},
	) or die "Cannot create socket client - $IO::Socket::errstr";

	$self->{client} = IO::Async::Stream->new(
		handle => $socket,
		on_read => $on_message,
	);

	return $self->{client};
}

1;

