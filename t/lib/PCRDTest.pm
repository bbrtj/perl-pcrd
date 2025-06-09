package PCRDTest;

use v5.14;
use warnings;
use Scalar::Util qw(looks_like_number);
use File::Temp qw(tempfile);

use Data::Dumper;
use Test2::Tools::Basic;
use Test2::Tools::Compare;
use IO::Socket::UNIX;
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use PCRD;
use PCRD::Client::Query;
use PCRD::Client::UserAgent;
use PCRD::Config::Memory;
use PCRDFiles;

## ATTRS (no mite possible in t/lib)

sub loop
{
	return $_[0]->{loop} //= IO::Async::Loop->new;
}

sub config
{
	return $_[0]->{config};
}

sub daemon
{
	return $_[0]->{daemon} //= $_[0]->_build_daemon;
}

sub user_agent
{
	return $_[0]->{user_agent} //= $_[0]->_build_user_agent;
}

sub client
{
	return $_[0]->{client} //= $_[0]->_build_client;
}

sub msgs
{
	return $_[0]->{msgs} //= {
		got => [],
		expected => [],
	};
}

sub timers
{
	return $_[0]->{timers} //= [];
}

## CODE

sub new
{
	my ($class, %args) = @_;

	my $self = bless {%args}, $class;

	$self->daemon;
	$self->user_agent;
	$self->client;

	return $self;
}

sub _build_daemon
{
	my ($self) = @_;

	my $config = $self->config;
	(undef, $config->{socket}{file}) = tempfile('sockXXXX', DIR => PCRDFiles->dir, OPEN => 0);

	my $daemon = PCRD->new(
		config_obj => PCRD::Config::Memory->new(
			values => $config,
		)
	);

	# early register socket, so that it will be created for the client
	$daemon->listener;
	$self->loop->add($daemon->notifier);

	return $daemon;
}

sub _build_user_agent
{
	my ($self) = @_;

	my $agent = PCRD::Client::UserAgent->new(
		config_obj => $self->daemon->config_obj,
	);

	return $agent;
}

sub _build_client
{
	my ($self) = @_;

	my $client = PCRD::Client::Query->new(
		config_obj => $self->daemon->config_obj,
		on_message => sub {
			my ($ok, $data) = @_;
			push @{$self->msgs->{got}}, [$ok, $data];
		},
	);

	return $client;
}

sub test_message
{
	my ($self, $args, $expected, $name_extra) = @_;

	my $name = join('.', @{$args}) . ' ok';
	$name .= " ($name_extra)" if defined $name_extra;

	$self->client->send(@$args);
	push @{$self->msgs->{expected}}, [$expected, $name];
}

sub run_tests
{
	my ($self) = @_;

	for my $i (keys @{$self->msgs->{got}}) {
		my ($success, $got) = @{$self->msgs->{got}[$i]};
		my ($expected, $message) = @{$self->msgs->{expected}[$i]};

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

	my $sent = @{$self->msgs->{expected}};
	my $got = @{$self->msgs->{got}};
	if ($sent != $got) {
		fail("Sent $sent messages but only got $got back");
		diag 'No responses for: ' . Dumper(@{$self->msgs->{expected}}[$got .. $sent - 1]);
	}
}

sub add_test_timer
{
	my ($self, $timer) = @_;

	push @{$self->timers}, $timer;
	$self->loop->add($timer);
}

sub start_cases
{
	my ($self, $cases, $case_time, $finalization_timeout) = @_;
	$case_time //= 0.02;

	my $timeout = (@$cases + 2) * $case_time;
	$self->add_test_timer(
		IO::Async::Timer::Periodic->new(
			interval => $case_time,
			on_tick => sub {
				$self->test_message(@{shift @$cases})
					if @$cases;
			},
		)
	);

	$self->start($timeout, $finalization_timeout);
}

sub start
{
	my ($self, $timeout, $finalization_timeout) = @_;
	$timeout //= 0.5;
	$finalization_timeout //= 0.05;

	if (@{$self->timers}) {
		$timeout += 0.05;
		$self->loop->add(
			IO::Async::Timer::Countdown->new(
				delay => 0.05,
				on_expire => sub {
					foreach my $timer (@{$self->timers}) {
						$timer->start;
					}
				},
			)->start
		);
	}

	# test timers will be removed after $timeout, then the loop will be given
	# additional 0.05 sec to respond to all signals
	if ($timeout) {
		$self->loop->add(
			IO::Async::Timer::Countdown->new(
				delay => $timeout,
				on_expire => sub {
					foreach my $timer (@{$self->timers}) {
						$timer->stop;
					}
				},
			)->start
		) if @{$self->timers};

		$self->loop->add(
			IO::Async::Timer::Countdown->new(
				delay => $timeout + $finalization_timeout,
				on_expire => sub {
					$self->stop;
				},
			)->start
		);
	}

	$self->daemon->start;
	$self->user_agent->start($self->loop);
	$self->client->start($self->loop);
	$self->loop->run;
}

sub stop
{
	my ($self) = @_;

	$self->loop->stop;
}

1;

