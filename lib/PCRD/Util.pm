package PCRD::Util;

use v5.14;
use warnings;
use autodie;

sub slurp
{
	my ($file) = @_;
	open my $fh, '<', $file;

	local $/;
	return scalar readline $fh;
}

sub spew
{
	my ($file, $content) = @_;
	open my $fh, '>', $file;

	print {$fh} $content;
}

sub slurp_1
{
	my ($file) = @_;
	open my $fh, '<', $file;

	my $value = readline $fh;
	chomp $value;
	return $value;
}

1;

