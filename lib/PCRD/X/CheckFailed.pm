package PCRD::X::CheckFailed;

use v5.14;
use warnings;

use PCRD::Mite;

extends 'PCRD::X';

our $FATAL = $ENV{PCRD_CHECK_FATAL};

use constant ERROR_TEXT => {
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

has 'feature_part' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

sub raise
{
	my ($self, $message, $feature, $feature_part) = @_;

	return $self->new(
		message => $message,
		feature => $feature,
		feature_part => $feature_part,
	)->raise unless ref $self;

	if ($FATAL) {
		die $self;
	}
	else {
		warn $self;
	}
}

sub error_string
{
	my ($self) = @_;

	return join "\n", grep { defined } $self->feature->desc, $self->feature->info;
}

sub stringify
{
	my ($self) = @_;

	my $feature = $self->feature;
	my $feature_name = $feature->owner->name . '.' . $feature->name;

	my $error_text = ERROR_TEXT->{$self->message};
	return sprintf <<MESSAGE, $feature_name, $self->feature_part, $self->error_string, $feature->dump_config;
'%s' will not work properly with current configuration.
$error_text
%s
Current config:
%s
MESSAGE
}

1;

