package PCRD::Module::Linux::Display;

use v5.14;
use warnings;

use List::Util qw(max min);

use parent 'PCRD::Module::Display';

sub prepare_brightness
{
	my ($self, $feature) = @_;

	@{$feature->{vars}{now_files}} = glob $feature->{config}{now_pattern};
	@{$feature->{vars}{max_files}} = glob $feature->{config}{max_pattern};
}

sub check_brightness
{
	my ($self, $feature) = @_;

	return ['unique', 'now_pattern'] unless @{$feature->{vars}{now_files}} == 1;
	return ['readable', 'now_pattern'] unless -r $feature->{vars}{now_files}[0];
	return ['writable', 'now_pattern'] unless -w $feature->{vars}{now_files}[0];

	return ['unique', 'now_pattern'] unless @{$feature->{vars}{max_files}} == 1;
	return ['readable', 'now_pattern'] unless -r $feature->{vars}{max_files}[0];

	return undef;
}

sub get_brightness
{
	my ($self, $feature) = @_;

	my $curr = PCRD::Util::slurp_1($feature->{vars}{now_files}[0]);
	my $max = PCRD::Util::slurp_1($feature->{vars}{max_files}[0]);
	return $curr > 0 ? int(log($curr) / log($max) * 100) / 100 : 0;
}

sub set_brightness
{
	my ($self, $feature, $direction) = @_;

	die 'invalid direction: must be either 1 or -1 (up or down)'
		unless $direction && $direction =~ m/^-?1$/;

	my $curr = PCRD::Util::slurp_1($feature->{vars}{now_files}[0]);
	my $max = PCRD::Util::slurp_1($feature->{vars}{max_files}[0]);
	my $new_curr;

	if ($curr == 0) {

		# can't take log of 0
		$new_curr = $direction > 0 ? 1 : 0;
	}
	else {
		my $new_log_scale_curr = log($curr) + $direction * 0.1 * log($max);
		$new_curr = max 0, min $max, int(exp($new_log_scale_curr));
	}

	PCRD::Util::spew($feature->{vars}{now_files}[0], $new_curr);
	return 1;
}

sub _build_features
{
	my ($self) = @_;
	my $features = $self->SUPER::_build_features;

	$features->{brightness}{info} = 'Display brightness is in a file usually located under /sys directory';
	$features->{brightness}{config} = {
		%{$features->{brightness}{config} // {}},
		now_pattern => {
			desc => 'glob file pattern for current brightness',
			value => '/sys/class/backlight/*/brightness',
		},
		max_pattern => {
			desc => 'glob file pattern for max brightness',
			value => '/sys/class/backlight/*/max_brightness',
		},
	};

	return $features;
}

1;

