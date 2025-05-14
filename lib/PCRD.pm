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

# socket constants (vars for easier interpolation)
my $ps = "\t";    # protocol separator
my $ok = 'ok';    # success
my $err = 'err';    # error

sub new
{
	my ($class, %args) = @_;
	my $self = bless \%args, $class;

	$self->{loop} = IO::Async::Loop->new;
	$self->_load_config;
	$self->_load_modules;
	return $self;
}

sub _load_config
{
	my ($self) = @_;

	$self->{_config} //= PCRD::Config->new;
	$self->{probe_interval} = $self->{_config}->get_value('probe_interval', 10);
	$self->{socket} = $self->{_config}->get_value('socket', {});
	$self->{socket}{file} //= '/var/run/pcrd.sock';
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

	die 'no modules specified, nothing to do'
		unless @module_list > 0;

	my @modules;
	my @loading_errors;

	foreach my $module (@module_list) {
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

sub start
{
	my ($self) = @_;

	die "PCRD is not capable of running on this system with current configuration\n"
		unless $self->check_modules;

	foreach my $module (keys %{$self->{modules}}) {
		$self->{modules}{$module}->init;
	}

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

