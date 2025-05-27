package PCRD;

use v5.14;
use warnings;
use autodie;
use IO::Socket::UNIX;
use IO::Async::Listener;
use IO::Async::Loop;
use Scalar::Util qw(looks_like_number);
use Fcntl qw(LOCK_EX LOCK_NB);
use English;

use PCRD::Util;
use PCRD::Module;

use PCRD::Mite;

extends 'PCRD::ConfiguredObject';

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error
my $eot = "\n";    # end of transmission

has 'loop' => (
	is => 'ro',
	default => sub {
		IO::Async::Loop->new;
	},
	init_arg => undef,
);

has 'probe_interval' => (
	is => 'ro',
	isa => 'PositiveNum',
	default => sub {
		shift->config_obj->get_value('probe_interval', 10);
	},
	lazy => 1,
	init_arg => undef,
);

has 'socket_config' => (
	is => 'ro',
	isa => 'HashRef',
	default => sub {
		my $hash = shift->config_obj->get_value('socket', {});
		$hash->{file} //= '/tmp/pcrd.sock';
		$hash->{user} //= $EUID;
		$hash->{group} //= $EGID;
		$hash->{perm} //= '0660';

		return $hash;
	},
	lazy => 1,
	init_arg => undef,
);

has 'modules' => (
	is => 'ro',
	isa => 'HashRef',
	builder => '_build_modules',
	lazy => 1,
	init_arg => undef,
);

has 'socket' => (
	is => 'ro',
	builder => '_build_socket',
	lazy => 1,
	init_arg => undef,
);

has 'listener' => (
	is => 'ro',
	isa => "InstanceOf['IO::Async::Listener']",
	builder => '_build_listener',
	lazy => 1,
	init_arg => undef,
);

sub _build_modules
{
	my ($self) = @_;

	my $config = $self->config_obj->get_values;
	my @module_list;
	foreach my $key (keys %$config) {
		next unless $key =~ m/^[A-Z]/;
		next unless $config->{$key}{enabled};

		# modules have first letter uppercase in config, and must have enabled => 1
		# (no modules by default)
		push @module_list, $key;
	}

	my @modules;
	my @loading_errors;

	foreach my $module (@module_list) {
		PCRD::Module->load_plugin($config->{$module}{plugin})
			if $config->{$module}{plugin};

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

	return {
		map { $_->name => $_->new(owner => $self) } @modules
	};
}

sub _build_socket
{
	my ($self) = @_;

	my $socket_conf = $self->socket_config;
	my $lockfile = $socket_conf->{file} . '.lock';
	open my $lock_fh, '>>', $lockfile;
	flock $lock_fh, LOCK_EX | LOCK_NB or die 'Could not obtain lock - server is running?';
	$socket_conf->{lock} = $lock_fh;

	unlink $socket_conf->{file}
		if -e $socket_conf->{file};

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Local => $socket_conf->{file},
		Listen => 1,
	) or die "Cannot create server socket - $IO::Socket::errstr\n";

	my $uid = $socket_conf->{user};
	$uid = getpwnam($uid)
		unless looks_like_number($uid);

	my ($gid) = split / /, $socket_conf->{group};
	$gid = getgrnam($gid)
		unless looks_like_number($gid);

	my $perm = oct($socket_conf->{perm});

	chown $uid, $gid, $socket_conf->{file};
	chmod $perm, $socket_conf->{file};

	return $socket;
}

sub _build_listener
{
	my ($self) = @_;

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
		handle => $self->socket,
	);

	return $listener;
}

sub dump_config
{
	my ($self) = @_;
	$self->config_obj->dump_config;
}

sub explain_config
{
	my ($self) = @_;
	$self->config_obj->explain_config(values %{$self->modules});
}

sub check_modules
{
	my ($self) = @_;
	my $modules = $self->modules;

	# TODO: translations?
	state $error_text = {
		'unique' => "Zero or multiple files found by pattern '%s'",
		'found' => "Zero files found by pattern '%s'",
		'readable' => "Files found by pattern '%s' are not readable",
		'writable' => "Files found by pattern '%s' are not writable",
		'command' => "Command does not run: %s",
		'dependency' => "Failure to resolve dependency on feature '%s'",
		'result' => "Unexpected result of querying the device's resource '%s'",
	};

	my %checklist;
	foreach my $module (values %$modules) {
		%checklist = (%checklist, %{$module->check});
	}

	my $success = !!1;
	foreach my $item (sort keys %checklist) {
		print "Checking '$item'... ";

		my $this_error = $checklist{$item}->check;
		$success &&= !defined $this_error;

		if (defined $this_error) {
			say 'ERROR!';
			warn sprintf($error_text->{$this_error->[0]}, $this_error->[1]) . "\n";
			warn "'$item' will not work properly with current configuration.\n";
			warn $checklist{$item}->error_string . "\n";
			warn "Current config:\n" . $checklist{$item}->dump_config . "\n";
			warn "\n";
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

	return $self->modules->{$name} // die "No such module: $name";
}

sub handle_message
{
	my ($self, $stream, $buffref, $eof) = @_;
	my $write = sub {
		my ($prefix, $message) = @_;

		say "< $message";
		$stream->write("${prefix}${ps}${message}$eot");
	};

	while ($$buffref =~ s/^(.*)$eot//) {
		say "> $1";
		my ($module, $feature_name, $action, $value) = split /$ps/, $1, 4;

		if (!$self->modules->{$module}) {
			$write->($err, "no module '$module'");
			next;
		}

		my $feature = $self->modules->{$module}->features->{$feature_name};
		if (!$feature) {
			$write->($err, "module '$module' does not have feature '$feature_name'");
			next;
		}

		if (!$feature->provides($action)) {
			$write->($err, "feature '$feature_name' from module '$module' does not provide action '$action'");
			next;
		}

		my $result;
		my $ex = PCRD::Util::try {
			$result = $feature->execute($action, $value);
		};

		if ($ex) {
			$ex =~ s/\n//g;
			$write->($err, $ex);
			next;
		}

		$write->($ok, $result);
	}
}

sub start
{
	my ($self) = @_;

	die "PCRD is not capable of running on this system with current configuration\n"
		unless $self->check_modules;

	die 'no modules specified, nothing to do'
		unless keys %{$self->modules};

	foreach my $module (keys %{$self->modules}) {
		$self->modules->{$module}->init;
	}

	say 'starting the daemon...';
	$self->listener;
	$self->loop->run;
}

sub stop
{
	my ($self) = @_;

	$self->loop->stop;
}

1;

__END__

=head1 NAME

PCRD - Parameters Control and Reporting Daemon

=head1 SYNOPSIS

	use PCRD;

	my $daemon = $pcrd->new;
	$daemon->start;

=head1 DESCRIPTION

This module is a daemon that collects and controls some OS details and can be
interacted with through a unix socket.

See L<pcrctl> for command line options. Quickstart:

=over

=item *

C<pcrctl init> will create an initial configuration file with all default
modules turned on.

=item *

C<pcrctl config> will list all configuration values.

=back

=head1 AUTHOR

Bartosz Jarzyna E<lt>bbrtj.pro@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Bartosz Jarzyna

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

