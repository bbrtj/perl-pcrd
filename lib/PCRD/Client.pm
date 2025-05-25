package PCRD::Client;

use v5.14;
use warnings;

use IO::Socket::UNIX;
use IO::Async::Stream;

use PCRD::Mite;

extends 'PCRD::ConfiguredObject';

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error
my $eot = "\n";    # end of transmission

has 'socket_config' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {
		my $hash = shift->config_obj->get_value('socket', {});
		$hash->{file} //= '/tmp/pcrd.sock';

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

has 'client' => (
	is => 'ro',
	isa => "InstanceOf['IO::Async::Stream']",
	builder => '_build_client',
	lazy => 1,
	init_arg => undef,
);

sub _build_client
{
	my ($self) = @_;

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Peer => $self->socket_config->{file},
	) or die "Cannot create socket client - $IO::Socket::errstr";

	my $on_message = $self->on_message;
	return IO::Async::Stream->new(
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
}

sub send
{
	my ($self, $module, $feature, $value) = @_;
	my $action = defined $value ? 'w' : 'r';

	$self->client->write(join($ps, grep { defined } $module, $feature, $action, $value) . $eot);
}

1;

