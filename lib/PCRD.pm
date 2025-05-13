package PCRD;

use v5.14;
use warnings;
use autodie;
use IO::Socket::UNIX;
use IO::Async::Listener;
use IO::Async::Loop;
use Scalar::Util qw(looks_like_number);
use English;

use PCRD::Config;
use PCRD::Util;
use PCRD::Module;

use constant MODULES_CONFIG => ['modules', [qw(Power)]];
use constant SOCKET_CONFIG => ['socket', '/var/run/pcrd.sock'];
use constant SOCKET_USER_CONFIG => ['socket_permissions', $UID];
use constant SOCKET_GROUP_CONFIG => ['socket_permissions', $GID];
use constant SOCKET_PERMISSIONS_CONFIG => ['socket_permissions', '0660'];

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error

sub new
{
	my ($class, %args) = @_;
	my $self = bless \%args, $class;

	$self->{config} //= PCRD::Config->instance;
	$self->{loop} = IO::Async::Loop->new;
	$self->load_modules;
	return $self;
}

sub load_modules
{
	my ($self) = @_;

	my $module_list = $self->{config}->get_value(@{(MODULES_CONFIG)});
	my @modules;
	my @loading_errors;

	foreach my $module (@$module_list) {
		my $loaded = PCRD::Module->get_implementation($module, \my $error);

		if (!$loaded) {
			push @loading_errors, $error;
			next;
		}

		push @modules, $loaded;
	}

	if (@loading_errors) {
		local $" = "\n";
		die "Some pcrd modules could not be loaded:\n@loading_errors\n";
	}

	$self->{modules} = {
		map { $_->name => $_->new(daemon => $self) } @modules
	};
}

sub check_modules
{
	my ($self) = @_;
	my $modules = $self->{modules};

	my %checklist;
	foreach my $module (values %$modules) {
		%checklist = (%checklist, %{$module->check});
	}

	my $success = !!1;
	foreach my $item (sort keys %checklist) {
		print "Checking '$item'... ";

		my $this_success = $checklist{$item}->check;
		$success &&= $this_success;

		if (!$this_success) {
			say 'error!';
			say "'$item' will not work properly with current configuration.";
			say $checklist{$item}->error;
		}
		else {
			say 'ok';
		}
	}

	return $success;
}

sub module
{
	my ($self, $name) = @_;

	return $self->{modules}{$name} // die "No such module: $name";
}

sub handle_message
{
	my ($self, $stream, $buffref, $eof) = @_;

	while ($$buffref =~ s/^(.*)\n//) {
		my ($module, $feature_name, $action, $value) = split /$ps/, $1, 4;

		if (!$self->{modules}{$module}) {
			$stream->write("${err}${ps}no module $module\n");
			return;
		}

		my $feature = $self->{modules}{$module}->feature($feature_name);
		if (!$feature) {
			$stream->write("${err}${ps}module $module does not have feature $feature_name\n");
			return;
		}

		if (!$feature->provides($action)) {
			$stream->write("${err}${ps}feature $feature_name from module $module does not provide action $action\n");
			return;
		}

		my $result;
		my $ex = PCRD::Util::try {
			$result = $feature->execute($action, $value);
		};

		if ($ex) {
			$ex =~ s/\n//g;
			$stream->write("${err}${ps}$ex\n");
			return;
		}

		$stream->write("${ok}${ps}$result\n");
	}
}

sub register_listener
{
	my ($self) = @_;
	return if $self->{listener};

	my $socket_file = $self->{config}->get_value(@{(SOCKET_CONFIG)});
	my $server = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Local => $socket_file,
		Listen => 1,
	) or die "Cannot create server socket - $IO::Socket::errstr\n";

	my $uid = $self->{config}->get_value(@{(SOCKET_USER_CONFIG)});
	$uid = getpwnam($uid)
		unless looks_like_number($uid);

	my ($gid) = split / /, $self->{config}->get_value(@{(SOCKET_GROUP_CONFIG)});
	$gid = getgrnam($gid)
		unless looks_like_number($gid);

	my $perm = oct($self->{config}->get_value(@{(SOCKET_PERMISSIONS_CONFIG)}));

	chown $uid, $gid, $socket_file;
	chmod $perm, $socket_file;

	my $listener = IO::Async::Listener->new(
		on_stream => sub {
			my (undef, $stream) = @_;

			$stream->configure(
				on_read => sub {
					$self->handle_message(@_);
					return 0;
				}
			);

			$self->{loop}->add($stream);
		}
	);

	$self->{loop}->add($listener);
	$listener->listen(
		handle => $server,
	);

	$self->{listener} = $listener;
}

sub start
{
	my ($self) = @_;

	die "Your system is not capable of running all the specified modules\n"
		unless $self->check_modules;

	foreach my $module (keys %{$self->{modules}}) {
		$self->{modules}{$module}->init;
	}

	$self->register_listener;
	$self->{loop}->run;
}

sub stop
{
	my ($self) = @_;

	$self->{loop}->stop;
}

1;

__END__

=head1 NAME

PCRD - New module

=head1 SYNOPSIS

	use PCRD;

	# do something

=head1 DESCRIPTION

This module lets you blah blah blah.

=head1 SEE ALSO

L<Some::Module>

=head1 AUTHOR

Bartosz Jarzyna E<lt>bbrtj.pro@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Bartosz Jarzyna

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

