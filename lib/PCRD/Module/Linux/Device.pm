package PCRD::Module::Linux::Device;

use v5.14;
use warnings;

use parent 'PCRD::Module::Device';

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
	return scalar($liddata =~ /\bopen\b/i);
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

	return $features;
}

1;

