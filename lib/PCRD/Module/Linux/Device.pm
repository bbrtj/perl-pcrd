package PCRD::Module::Linux::Device;

use v5.14;
use warnings;

use parent 'PCRD::Module::Any::Device';

## LID

sub prepare_lid
{
	my ($self, $feature) = @_;

	$feature->vars->{files} = [glob $feature->config->{pattern}];
}

sub check_lid
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['readable', 'pattern'] unless -r @{$feature->vars->{files}}[0];
	return undef;
}

sub get_lid
{
	my ($self, $feature) = @_;

	my $liddata = PCRD::Util::slurp_1($feature->vars->{files}[0]);
	return PCRD::Bool->new(scalar($liddata =~ /\bopen\b/i));
}

## SUSPEND

sub prepare_suspend
{
	my ($self, $feature) = @_;

	@{$feature->vars->{files}} = glob $feature->config->{pattern};
}

sub check_suspend
{
	my ($self, $feature) = @_;

	return ['unique', 'pattern'] unless @{$feature->vars->{files}} == 1;
	return ['writable', 'pattern'] unless -w $feature->vars->{files}[0];
	return undef;
}

sub set_suspend
{
	my ($self, $feature, $value) = @_;

	return PCRD::Util::execute_if_true(
		$value,
		sub {
			PCRD::Util::spew($feature->vars->{files}[0], $feature->config->{state});
		}
	);
}

sub _build_features
{
	my ($self) = @_;
	my $features = $self->SUPER::_build_features;

	$features->{lid}{info} = 'Lid state is in a file usually located under /proc directory';
	$features->{lid}{config} = {
		%{$features->{lid}{config} // {}},
		pattern => {
			desc => 'glob file pattern for lid state',
			value => '/proc/acpi/button/lid/LID*/state',
		},
	};

	$features->{suspend}{info} = 'Suspend is done by writing to a file usually found under /sys directory';
	$features->{suspend}{config} = {
		%{$features->{suspend}{config} // {}},
		pattern => {
			desc => 'glob file pattern',
			value => '/sys/power/state',
		},
		state => {
			desc => 'state to which the machine should be put',
			value => 'mem',
		},
	};

	return $features;
}

1;

