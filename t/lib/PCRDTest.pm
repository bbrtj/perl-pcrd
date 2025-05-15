package PCRDTest;

use v5.14;
use warnings;
use File::Temp qw(tempfile tempdir);
use Scalar::Util qw(looks_like_number);

use Data::Dumper;
use Test2::Tools::Basic;
use Test2::Tools::Compare;
use IO::Socket::UNIX;
use IO::Async::Stream;
use IO::Async::Timer::Countdown;
use PCRD;
use PCRD::Client;
use PCRD::Config::Memory;

sub new
{
	my ($class) = @_;
	my $dir = tempdir('pcrdXXXX', CLEANUP => 1);

	return bless {dir => $dir}, $class;
}

sub _update
{
	my ($self, $fh, $value) = @_;

	local $| = 1;
	print {$fh} $value;
	seek $fh, 0, 0;
}

sub prepare_tmpfile
{
	my ($self, $name, $contents) = @_;
	my ($fh, $file) = tempfile("${name}XXXX", DIR => $self->{dir});
	$self->_update($fh, $contents);

	$self->{files}{$name} = {
		fh => $fh,
		file => $file,
	};

	return $file;
}

sub update
{
	my ($self, $name, $contents) = @_;
	$self->_update($self->{files}{$name}{fh}, $contents);
}

sub create_daemon
{
	my ($self, %config) = @_;
	return if $self->{pcrd};

	(undef, $config{socket}{file}) = tempfile('sockXXXX', DIR => $self->{dir}, OPEN => 0);
	my $memory_config = PCRD::Config::Memory->new(
		values => \%config,
	);

	$self->{pcrd} = PCRD->new(_config => $memory_config);

	# early register socket, so that it will be created for the client
	$self->{pcrd}->_register_listener;
	$self->_create_client($memory_config);

	return $self;
}

sub _create_client
{
	my ($self, $memory_config) = @_;

	my $client = PCRD::Client->new(_config => $memory_config);

	$self->{msgs}{got} = [];
	$self->{msgs}{expected} = [];

	$self->{client} = $client->setup(
		sub {
			my ($stream, $buffref, $eof) = @_;

			while ($$buffref =~ s/^(.*)\n//) {
				my ($status, $data) = split /\t/, $1;
				push @{$self->{msgs}{got}}, [$status eq 'ok', $data];
			}

			return 0;
		}
	);

	$self->loop->add($self->{client});
}

sub test_message
{
	my ($self, $args, $expected, $name_extra) = @_;

	my $name = join('.', @{$args}[0 .. 2]) . ' ok';
	$name .= " ($name_extra)" if defined $name_extra;

	$self->{client}->write(join("\t", @$args) . "\n");
	push @{$self->{msgs}{expected}}, [$expected, $name];
}

sub run_tests
{
	my ($self) = @_;

	for my $i (keys @{$self->{msgs}{got}}) {
		my ($success, $got) = @{$self->{msgs}{got}[$i]};
		my ($expected, $message) = @{$self->{msgs}{expected}[$i]};

		ok($success, 'response message was success');
		if (ref $expected eq 'CODE') {
			local $_ = $got;
			ok($expected->(), "$message (got $got)");
		}
		else {
			if (looks_like_number($expected) && int($expected) != $expected) {
				$expected = int($expected * 1e6) / 1e6;
				$got = int($got * 1e6) / 1e6
					if looks_like_number($got);
			}

			is($got, $expected, $message);
		}
	}

	my $sent = @{$self->{msgs}{expected}};
	my $got = @{$self->{msgs}{got}};
	if ($sent != $got) {
		fail("Sent $sent messages but only got $got back");
		diag 'No responses for: ' . Dumper(@{$self->{msgs}{expected}}[$got .. $sent - 1]);
	}
}

sub add_test_timer
{
	my ($self, $timer) = @_;

	push @{$self->{timers}}, $timer;
	$self->loop->add($timer);
}

sub start
{
	my ($self, $timeout, $finalization_timeout) = @_;
	$timeout //= 0.5;
	$finalization_timeout //= 0.05;

	# test timers will be removed after $timeout, then the loop will be given
	# additional 0.05 sec to respond to all signals
	if ($timeout) {
		$self->loop->add(
			IO::Async::Timer::Countdown->new(
				delay => $timeout,
				on_expire => sub {
					foreach my $timer (@{$self->{timers}}) {
						$timer->stop;
					}
				},
			)->start
		) if $self->{timers};

		$self->loop->add(
			IO::Async::Timer::Countdown->new(
				delay => $timeout + $finalization_timeout,
				on_expire => sub {
					$self->stop;
				},
			)->start
		);
	}

	$self->{pcrd}->start;
}

sub stop
{
	my ($self) = @_;

	$self->{pcrd}->stop;
}

sub loop
{
	my ($self) = @_;

	$self->{pcrd}{loop};
}

1;

