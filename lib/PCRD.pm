package PCRD;

use v5.14;
use warnings;
use IO::Async::Loop;

use PCRD::Config;
use PCRD::Util;
use PCRD::Module;

use constant MODULES_CONFIG => ['modules', [qw(Power)]];

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

		push @modules, $loaded
	}

	if (@loading_errors) {
		local $" = "\n";
		die "Some pcrd modules could not be loaded:\n@loading_errors\n"
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

		my $this_success = $checklist{$item}{check}->();
		$success &&= $this_success;

		if (!$this_success) {
			say 'error!';
			say "'$item' will not work properly with current configuration.";
			say $checklist{$item}{error};
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

sub start
{
	my ($self) = @_;

	die "Your system is not capable of running all the specified modules\n"
		unless $self->check_modules;

	# TODO: set up external signal handling
	foreach my $module (keys %{$self->{modules}}) {
		$self->{modules}{$module}->init;
	}

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

