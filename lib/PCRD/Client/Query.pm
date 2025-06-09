package PCRD::Client::Query;

use v5.14;
use warnings;

use PCRD::Mite;
use PCRD::Protocol;

extends 'PCRD::Client';

sub _message_handler
{
	my ($self) = @_;
	my $on_message = $self->on_message;

	return sub {
		my ($stream, $buffref, $eof) = @_;

		while (my @parts = PCRD::Protocol::extract_message($buffref, 2)) {
			my ($status, $data) = @parts;
			$on_message->(PCRD::Protocol::status_to_bool($status), $data);
		}

		return 0;
	};
}

sub send
{
	my ($self, $module, $feature, $value) = @_;
	my $action = defined $value ? 'w' : 'r';

	$self->SUPER::send($module, $feature, $action, $value);
}

after 'start' => sub {
	my ($self) = @_;

	$self->SUPER::send(PCRD::Protocol::handshake('query'));
};

1;

