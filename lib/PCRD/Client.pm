package PCRD::Client;

use v5.14;
use warnings;

use IO::Socket::UNIX;
use IO::Async::Stream;

use parent 'PCRD::ConfiguredObject';

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error
my $eot = "\n";    # end of transmission

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

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Peer => $self->{socket}{file},
	) or die "Cannot create socket client - $IO::Socket::errstr";

	$self->{client} = IO::Async::Stream->new(
		handle => $socket,
		on_read => sub {
			my ($stream, $buffref, $eof) = @_;

			while ($$buffref =~ s/^(.*)$eot//) {
				my ($status, $data) = split /$ps/, $1, 2;
				$on_message->($status eq $ok, $data);
			}

			return 0;
		}
	);

	return $self->{client};
}

sub send
{
	my ($self, $module, $feature, $value) = @_;
	my $action = defined $value ? 'w' : 'r';

	$self->{client}->write(join($ps, grep { defined } $module, $feature, $action, $value) . $eot);
}

1;

