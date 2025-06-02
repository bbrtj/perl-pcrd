package PCRDFiles;

use v5.14;
use warnings;

use File::Temp qw(tempfile tempdir);

my %files;
my $dir = tempdir('pcrdXXXX', CLEANUP => 1);

sub dir
{
	return $dir;
}

sub _update
{
	my ($self, $fh, $value) = @_;

	local $| = 1;
	truncate $fh, 0;
	print {$fh} $value;
	seek $fh, 0, 0;
}

sub prepare
{
	my ($self, $name, $contents) = @_;
	my ($fh, $file) = tempfile("${name}XXXX", DIR => $self->dir);
	$self->_update($fh, $contents);

	$files{$name} = {
		fh => $fh,
		file => $file,
	};

	return $file;
}

sub update
{
	my ($self, $name, $contents) = @_;
	$self->_update($files{$name}{fh}, $contents);
}

sub contents
{
	my ($self, $name) = @_;
	my $fh = $files{$name}{fh};

	my @lines = readline $fh;
	seek $fh, 0, 0;

	return join '', @lines;
}

1;

