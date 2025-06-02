package PCRD::Protocol;

use v5.14;
use warnings;

use constant {
	SEPARATOR => "\t",
	SUCCESS => 'ok',
	ERROR => 'err',
	HANDSHAKE => '+',
	TERMINATOR => "\n---\n",
};

sub extract_message
{
	my ($buffref, $max_parts) = @_;
	$max_parts //= -1;

	my $eot = quotemeta TERMINATOR;
	if ($$buffref =~ s/^(.*?)$eot//s) {
		my $ps = quotemeta SEPARATOR;
		return split /$ps/, $1, $max_parts;
	}

	return ();
}

sub extract_handshake_message
{
	my ($buffref) = @_;

	my $eot = TERMINATOR;
	if ($$buffref =~ s/^(.*)$eot//) {
		my $ps = quotemeta SEPARATOR;
		my $hs = quotemeta HANDSHAKE;

		my @parts = split /$ps/, $1;

		return undef unless @parts == 1;
		return undef unless $parts[0] =~ s{^$hs}{};

		return $parts[0];
	}

	return undef;
}

sub message
{
	my (@parts) = @_;

	return join(SEPARATOR, @parts) . TERMINATOR;
}

sub message_success
{
	my (@parts) = @_;

	return message(SUCCESS, @parts);
}

sub message_error
{
	my (@parts) = @_;

	return message(ERROR, @parts);
}

sub bool_to_status
{
	my ($bool) = @_;

	return $bool ? SUCCESS : ERROR;
}

sub status_to_bool
{
	my ($status) = @_;

	return $status eq SUCCESS;
}

1;

