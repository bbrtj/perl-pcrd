package PCRD::CheckFailed;

use v5.14;
use warnings;

use PCRD::Mite;

my $error_text = {
	'unique' => "Zero or multiple files found by pattern '%s'",
	'found' => "Zero files found by pattern '%s'",
	'readable' => "Files found by pattern '%s' are not readable",
	'writable' => "Files found by pattern '%s' are not writable",
	'command' => "Command does not run: %s",
	'dependency' => "Failure to resolve dependency on feature '%s'",
	'result' => "Unexpected result of querying the device's resource '%s'",
	'config' => "Bad configuration value '%s'",
};

has 'feature' => (
	is => 'ro',
	isa => "InstanceOf ['PCRD::Feature']",
	required => 1,
);

has 'error' => (
	is => 'ro',
	isa => 'Tuple [Str, Str]',
	required => 1,
);

sub error_string
{
	my ($self) = @_;

	return join "\n", grep { defined } $self->feature->desc, $self->feature->info;
}

sub raise_warning
{
	my ($self) = @_;

	my $error = $self->error;
	my $feature = $self->feature;
	my $feature_name = $feature->owner->name . '.' . $feature->name;

	warn "'$feature_name' will not work properly with current configuration.\n";
	warn sprintf($error_text->{$error->[0]}, $error->[1]) . "\n";
	warn $self->error_string . "\n";
	warn "Current config:\n" . $feature->dump_config . "\n";
	warn "\n";
}

1;

