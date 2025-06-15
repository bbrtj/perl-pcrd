package PCRD::Protocol;

use v5.14;
use warnings;
use Encode qw(encode decode);

# all protocol parts must be plain ascii
use constant {
	SEPARATOR => "\t",
	SUCCESS => 'ok',
	ERROR => 'nok',
	HANDSHAKE => '+',
	TERMINATOR => "\n---\n",
	TRUE => 'true',
	FALSE => 'false',
};

sub extract_message
{
	my ($buffref, $max_parts) = @_;
	$max_parts //= -1;

	state $eot = quotemeta TERMINATOR;
	state $ps = quotemeta SEPARATOR;

	if ($$buffref =~ s/^(.*?)$eot//s) {
		my $data = decode 'UTF-8', $1;
		return split /$ps/, $data, $max_parts;
	}

	return ();
}

sub extract_handshake_message
{
	my ($buffref) = @_;

	state $eot = TERMINATOR;
	state $hs = quotemeta HANDSHAKE;
	state $ps = quotemeta SEPARATOR;

	if ($$buffref =~ s/^$hs(.*)$eot//) {
		my $data = decode 'UTF-8', $1;
		my @parts = split /$ps/, $data;

		return undef unless @parts == 1;
		return $parts[0];
	}

	return undef;
}

sub message
{
	my (@parts) = @_;

	return encode 'UTF-8', join(SEPARATOR, @parts) . TERMINATOR;
}

# not standalone, must be paired with message
sub handshake
{
	my ($hs) = @_;

	return HANDSHAKE . $hs;
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

