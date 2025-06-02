package PCRD::Config::File;

use v5.14;
use warnings;

use PCRD::Mite;
use PCRD::Util;

extends 'PCRD::Config';

has 'filename' => (
	is => 'ro',
	isa => 'Str',
	default => sub {
		my $self = shift;
		return $ENV{PCRD_CONFIG} // "/etc/pcrd.conf";
	},
);

sub dump_config
{
	my ($self) = @_;

	my $filename = $self->filename;
	die "config file $filename already exists!\n"
		if -e $filename;

	PCRD::Util::spew($filename, join '', readline DATA);

	# TODO: roll DATA back to previous position to allow reuse
}

sub load_config
{
	my ($self) = @_;
	my %conf;

	if (-f $self->filename) {
		my @lines = PCRD::Util::slurp($self->filename);
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
	}

	$self->_set_values(\%conf);
}

1;

__DATA__
# This is a PCRD config file. Lines starting with a hash is are comments.
# You must enable all desired modules manually with Module.enabled=1
# configuration flag. Once a module is enabled, all of its features are enabled
# automatically. If that's not a desired behavior, Module.all_features=0 flag
# can be used.

Power.enabled=1
Performance.enabled=1
Display.enabled=1
Sound.enabled=1
System.enabled=1
Device.enabled=1

