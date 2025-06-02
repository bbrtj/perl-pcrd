package PCRD::Notifier;

use v5.14;
use warnings;

use parent 'IO::Async::Notifier';

sub on_loop
{
	my ($self, $callback, $unloop_callback) = @_;

	push @{$self->{loop_callbacks}}, $callback
		if $callback;
	push @{$self->{unloop_callbacks}}, $unloop_callback
		if $unloop_callback;
}

sub _add_to_loop
{
	my ($self, $loop) = @_;

	foreach my $callback (@{$self->{loop_callbacks} // []}) {
		$callback->($loop);
	}
}

sub _remove_from_loop
{
	my ($self, $loop) = @_;

	foreach my $callback (@{$self->{unloop_callbacks} // []}) {
		$callback->($loop);
	}
}

1;

