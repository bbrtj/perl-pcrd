package PCRD::Client::UserAgent;

use v5.14;
use warnings;

use Scalar::Util qw(weaken);

use PCRD::Util;
use PCRD::Protocol;

use PCRD::Mite;

extends 'PCRD::Client';

has '+on_message' => (
	builder => '_build_on_message',
	required => 0,
);

sub _build_on_message
{
	my ($self) = @_;
	weaken $self;

	return sub {
		my (@parts) = @_;
		my $id = shift @parts;

		my @lines;
		my $ex = PCRD::Util::try {
			@lines = PCRD::Util::slurp_command(@parts);
		};

		if (PCRD::Util::DEBUG) {
			my $command = join ' ', @parts;
			my $result = join '', @lines;
			warn "command <$command>, output: $result\n";
		}

		my @message = $ex
			? (PCRD::Protocol::bool_to_status(0), $id, $ex)
			: (PCRD::Protocol::bool_to_status(1), $id, @lines)
			;

		$self->send(@message);
	};
}

after 'start' => sub {
	my ($self) = @_;

	$self->send(PCRD::Protocol::handshake('user_agent'));
};

1;

