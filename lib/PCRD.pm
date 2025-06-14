package PCRD;

use v5.14;
use warnings;
use autodie;
use IO::Socket::UNIX;
use IO::Async::Listener;
use PCRD::Notifier;
use Scalar::Util qw(looks_like_number);
use Fcntl qw(LOCK_EX LOCK_NB);
use English;

use PCRD::Util;
use PCRD::Module;
use PCRD::Protocol;
use PCRD::Listener;

use PCRD::Mite;

extends 'PCRD::ConfiguredObject';

has 'notifier' => (
	is => 'ro',
	default => sub {
		PCRD::Notifier->new;
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
		$hash->{file} //= '/var/run/pcrd.sock';
		$hash->{pidfile} //= do {
			my $default_pidfile = $hash->{file};
			$default_pidfile =~ s/(\.sock)?$/.pid/;
			$default_pidfile;
		};
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
	isa => "InstanceOf['PCRD::Listener']",
	default => sub { PCRD::Listener->new(owner => $_[0]) },
	lazy => 1,
	init_arg => undef,
	handles => {
		broadcast => 'send_to_agent',
	},
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
		PCRD::Module->load_plugin($config->{$module}{plugin}, $module)
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
	my $pidfile = $socket_conf->{pidfile};
	my $lockfile = $pidfile . ".lock";
	open my $lock_fh, '>>', $lockfile;
	flock $lock_fh, LOCK_EX | LOCK_NB or die 'Could not obtain lock - server is running?';
	PCRD::Util::spew($pidfile, $PROCESS_ID);
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

sub prepare_modules
{
	my ($self, %args) = @_;
	my $modules = $self->modules;
	my @order = sort keys %$modules;

	foreach my $module (@order) {
		$modules->{$module}->prepare;
	}

	foreach my $module (@order) {
		$modules->{$module}->check(%args);
	}

	# after all features are checked, check their dependencies
	# TODO: this # should be done after all futures from the previous foreach are complete
	if (!$args{agent_present}) {
		foreach my $module (@order) {
			$modules->{$module}->check(%args, dependencies => 1);
		}
	}

	foreach my $module (@order) {
		$modules->{$module}->init(%args);
	}
}

sub agent_present
{
	my ($self) = @_;

	$self->prepare_modules(agent_present => 1);
}

sub agent_absent
{
	my ($self) = @_;

	$self->prepare_modules(agent_present => 0);
}

sub module
{
	my ($self, $name) = @_;

	return $self->modules->{$name} // die "No such module: $name";
}

sub start
{
	my ($self) = @_;

	die 'no modules specified, nothing to do'
		unless keys %{$self->modules};

	$self->prepare_modules;

	say 'starting the daemon...';
	$self->listener;
}

sub find_feature_module
{
	my ($self, $feature) = @_;
	my $modules = $self->modules;
	my @found;

	foreach my $module (keys %$modules) {
		if (exists $modules->{$module}->features->{$feature}) {
			push @found, $module;
		}
	}

	die "No modules supply feature '$feature'"
		if @found == 0;
	die "Multiple modules supply feature '$feature': " . join ', ', @found
		if @found > 1;

	return $found[0];
}

1;

__END__

=head1 NAME

PCRD - Parameters Control and Reporting Daemon

=head1 SYNOPSIS

	use PCRD;
	use IO::Async::Loop;

	my $loop = IO::Async::Loop->new;
	my $daemon = PCRD->new;
	$daemon->start;
	$loop->add($daemon->notifier);
	$loop->run;

=head1 DESCRIPTION

This module is a daemon that collects and controls some OS details and can be
interacted with through a unix socket.

=head2 Interface

See L<pcrd> and L<pcrctl> for command line options. Quickstart:

=over

=item

C<pcrd> runs the daemon. This should be done as root.

It puts output under C</var/log/pcrd.log> by default, which can be changed with
C<--logs> argument.

=item

C<pcrd user-agent> runs the user agent, which executes commands on behalf of
the user. This should be run as the user who runs the graphical environment.

User agent generates no output (other than errors when stuff go wrong), so no
log file is created for it. C<--logs> argument does nothing for it.

=item

C<pcrd init> will create an initial configuration file with all default
modules turned on.

=item

C<pcrctl config> will list all configuration values.

=back

=head2 Configuration

Config files reside in a directory configured via C<PCRD_DIR> environmental
variable (C</etc/pcrd> by default). C<pcrd.conf> file with config vars should
be present.

Configuration file should explicitly enable all modules which will be used by
PCRD.  Once a module is enabled, all of its features will be enabled
automatically. To prevent that, C<all_features> can be specified as C<0> is the
module's config, and all wanted features must be enabled explicitly:

	# do not automatically enable all features
	Module.enabled=1
	Module.all_features=0
	Module.feature.enabled=1

=head2 Plugins

Plugins can be put into C<plugins> directory under C<PCRD_DIR>. If they are,
they can be enabled with the following config:

	PluginModule.enabled=1
	PluginModule.plugin=1

C<plugins/PluginModule.pm> will be loaded and it should contain module package.

If plugins are outside of that directory, a full path to plugin file must be
specified. If additional modules are in C<@INC> then it is not requried to
specify C<Module.plugin>.

Each plugin is a single PCRD module. It must be under namespace
C<PCRD::Module::KERNEL::PluginModule> or C<PCRD::Module::Any::PluginModule>.
Core PCRD modules can serve as examples for any plugin modules.

=head2 Interacting with the daemon

To interact with the daemon, C<pcrctl> program can be used:

	# get value
	pcrctl Module feature

	# set value
	pcrctl Module feature "value"

It is recommended to configure pcrd to use C<wheel> as group for its socket, so
that it will not be open to any user, but will be possible to talk to it
without elevated permissions:

	socket.group=wheel

=head1 AUTHOR

Bartosz Jarzyna E<lt>bbrtj.pro@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Bartosz Jarzyna

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

