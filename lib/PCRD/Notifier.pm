package PCRD::Notifier;

use v5.14;
use warnings;

use Scalar::Util qw(blessed);

use parent 'IO::Async::Notifier';

sub new
{
	my ($class, %args) = @_;
	$args{on_error} = sub {
		my (undef, $message, $name, @details) = @_;

		return if blessed $message && $message->isa('PCRD::X::ExecutionFailed');

		$name = $name ? "[$name] " : '';
		say "ERROR: $name$message";
		say join "\n", @details if @details;
	};

	return $class->SUPER::new(%args);
}

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

