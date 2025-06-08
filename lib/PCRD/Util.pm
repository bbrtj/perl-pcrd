package PCRD::Util;

use v5.14;
use warnings;
use autodie;
use IPC::Open3;
use Symbol 'gensym';

sub slurp
{
	my ($file) = @_;
	open my $fh, '<', $file;

	return readline $fh;
}

sub slurp_command
{
	my (@command) = @_;

	my $pid = open3(undef, my $output, my $error = gensym, @command);

	my @contents = readline $output;
	my $errors = do {
		local $/;
		readline $error;
	};
	waitpid $pid, 0;

	my $status = $? >> 8;
	die "command failed: $errors" if $status != 0;

	return @contents;
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

sub try (&)
{
	my ($sub) = @_;

	local $@;
	my $ok = eval { $sub->(); 1 };

	return $ok ? undef : $@;
}

sub any (&@)
{
	my $sub = shift;
	$sub->($_) && return 1 for @_;
	return 0;
}

sub all (&@)
{
	my $sub = shift;
	$sub->($_) || return 0 for @_;
	return 1;
}

sub trim
{
	my $value = shift;
	$value =~ s/^\s*//;
	$value =~ s/\s*$//;
	return $value;
}

1;

