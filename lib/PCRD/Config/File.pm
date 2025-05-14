package PCRD::Config::File;

use v5.14;
use warnings;

use PCRD::Util;

use parent 'PCRD::Config';

sub load_config
{
	my ($self) = @_;

	my $filename = $self->{filename} // $ENV{PCRD_CONFIG} // "$ENV{HOME}/.pcrd";
	my @lines = PCRD::Util::slurp($filename);
	my %conf;

	chomp @lines;
	foreach my $line (@lines) {
		next unless $line =~ /\S/;
		next if $line =~ /^\s*#/;
		my ($key, $value) = split /=/, $line, 2;

		die "invalid configuration line: $line (no value)"
			unless defined $value;

		$key = PCRD::Util::trim($key);
		$value = PCRD::Util::trim($value);
		my @key_parts = split /\./, $key;
		$key = pop @key_parts;

		my $current_conf = \%conf;
		foreach my $kp (@key_parts) {
			die "invalid configuration: $line (path element $kp exists and not a hash)"
				if exists $current_conf->{$kp} && ref $current_conf->{$kp} ne 'HASH';
			$current_conf = $current_conf->{$kp} //= {};
		}

		die "duplicated configuration: $line (key exists)"
			if exists $current_conf->{$key};
		$current_conf->{$key} = $value;
	}

	$self->{values} = \%conf;
}

1;

