package PCRD::Util;

use v5.14;
use warnings;
use autodie;
use IPC::Open3;
use Symbol 'gensym';
use PCRD::Protocol;

sub slurp
{
	my ($file) = @_;
	open my $fh, '<:encoding(UTF-8)', $file;

	return readline $fh;
}

sub slurp_command
{
	my (@command) = @_;

	my $pid = open3(undef, my $output, my $error = gensym, @command);

	binmode $output, ':encoding(UTF-8)';
	binmode $error, ':encoding(UTF-8)';

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
	open my $fh, '>:encoding(UTF-8)', $file;

	print {$fh} $content;
}

sub slurp_1
{
	my ($file) = @_;
	open my $fh, '<:encoding(UTF-8)', $file;

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

sub generate_validator
{
	my (%args) = @_;
	require PCRD::X::BadArgument;

	my @possible = (
		($args{truefalse} ? (PCRD::Protocol::TRUE, PCRD::Protocol::FALSE) : ()),
		($args{custom} ? @{$args{custom}} : ()),
	);

	my $message = 'invalid argument, ';
	if ($args{hint}) {
		$message .= $args{hint};
	}
	elsif (@possible) {
		$message .= 'must be any of: ' . join ', ', @possible;
	}

	return sub {
		my $value = shift;
		my $result = defined $value;

		$result &&= $value =~ $args{re}
			if exists $args{re};

		$result &&= any { $_ eq $value } @possible
			if @possible;

		PCRD::X::BadArgument->raise($message) unless $result;
	};
}

sub execute_if_true
{
	my ($value, $sub) = @_;

	state $validator = generate_validator(truefalse => 1);
	$validator->($value);

	return PCRD::Bool->new(!!0) unless value_to_bool($value);
	$sub->();
	return PCRD::Bool->new(!!1);
}

sub value_to_bool
{
	my ($message) = @_;

	if ($message eq PCRD::Bool->new(!!1)) {
		return PCRD::Bool->new(!!1);
	}
	elsif ($message eq PCRD::Bool->new(!!0)) {
		return PCRD::Bool->new(!!0);
	}
	else {
		return undef;
	}
}

{

	package PCRD::Bool;

	use overload
		q{bool} => sub { !!${$_[0]} },
		q{""} => sub { ${$_[0]} ? PCRD::Protocol::TRUE : PCRD::Protocol::FALSE },
		fallback => 1,
		;

	sub new
	{
		# copy the value here, so we don't reference the value from outside the function
		my $value = $_[1];
		return bless \$value, $_[0];
	}
}

1;

