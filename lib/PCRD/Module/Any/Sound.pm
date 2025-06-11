package PCRD::Module::Any::Sound;

use v5.14;
use warnings;

use parent 'PCRD::Module';

use constant name => 'Sound';

sub check_volume { ... }
sub get_volume { ... }
sub set_volume { ... }

sub check_mute { ... }
sub get_mute { ... }
sub set_mute { ... }

sub check_mute_microphone { ... }
sub get_mute_microphone { ... }
sub set_mute_microphone { ... }

sub _build_features
{
	return {
		volume => {
			desc => 'Get current sound volume of the default audio sink',
			mode => 'rw',
			config => {
				step => {
					desc => 'volume will be increased / decreased by this value',
					value => 8,
				},
			},
		},
		mute => {
			desc => 'Get current mute status of the default audio sink',
			mode => 'rw',
		},
		mute_microphone => {
			desc => 'Get current mute status of the default audio source',
			mode => 'rw',
		},
	};
}

1;

