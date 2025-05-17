package PCRD;

use v5.14;
use warnings;
use autodie;
use IO::Socket::UNIX;
use IO::Async::Listener;
use IO::Async::Loop;
use Scalar::Util qw(looks_like_number);
use English;

use PCRD::Util;
use PCRD::Module;

use parent 'PCRD::ConfiguredObject';

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error
my $eot = "\n";    # end of transmission

sub new
{
	my $self = shift->SUPER::new(@_);

	$self->{loop} = IO::Async::Loop->new;
	$self->_load_modules;
	return $self;
}

sub _load_config
{
	my ($self) = @_;
	$self->SUPER::_load_config;

	$self->{probe_interval} = $self->{_config}->get_value('probe_interval', 10);
	$self->{socket} = $self->{_config}->get_value('socket', {});
	$self->{socket}{file} //= '/tmp/pcrd.sock';
	$self->{socket}{user} //= $EUID;
	$self->{socket}{group} //= $EGID;
	$self->{socket}{perm} //= '0660';
}

sub _load_modules
{
	my ($self) = @_;

	my $config = $self->{_config}->get_values;
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

	$self->{modules} = {
		map { $_->name => $_->new(pcrd => $self) } @modules
	};
}

sub _setup_socket
{
	my ($self) = @_;

	unlink $self->{socket}{file}
		if -e $self->{socket}{file};

	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM,
		Local => $self->{socket}{file},
		Listen => 1,
	) or die "Cannot create server socket - $IO::Socket::errstr\n";

	my $uid = $self->{socket}{user};
	$uid = getpwnam($uid)
		unless looks_like_number($uid);

	my ($gid) = split / /, $self->{socket}{group};
	$gid = getgrnam($gid)
		unless looks_like_number($gid);

	my $perm = oct($self->{socket}{perm});

	chown $uid, $gid, $self->{socket}{file};
	chmod $perm, $self->{socket}{file};

	return $socket;
}

sub _register_listener
{
	my ($self) = @_;
	return if $self->{listener};

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
		handle => $self->_setup_socket,
	);

	$self->{listener} = $listener;
}

sub dump_config
{
	my ($self) = @_;
	$self->{_config}->dump_config;
}

sub explain_config
{
	my ($self) = @_;
	$self->{_config}->explain_config(values %{$self->{modules}});
}

sub check_modules
{
	my ($self) = @_;
	my $modules = $self->{modules};

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
			warn "Current config:\n" . $checklist{$item}->explain_config . "\n";
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

	return $self->{modules}{$name} // die "No such module: $name";
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

		if (!$self->{modules}{$module}) {
			$write->($err, "no module '$module'");
			next;
		}

		my $feature = $self->{modules}{$module}->feature($feature_name);
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
		unless keys %{$self->{modules}};

	foreach my $module (keys %{$self->{modules}}) {
		$self->{modules}{$module}->init;
	}

	say 'starting the daemon...';
	$self->_register_listener;
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

