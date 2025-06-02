package PCRD::Stream;

use v5.14;
use warnings;

use Scalar::Util qw(weaken);

use PCRD::Mite;

use constant {
	TYPE_NONE => 0,
	TYPE_QUERY => 1,
	TYPE_USER_AGENT => 2,
};

use constant CLIENT_TYPES => [
	TYPE_NONE,
	TYPE_QUERY,
	TYPE_USER_AGENT,
];

has '_client_type' => (
	is => 'ro',
	isa => 'Enum [' . join(', ', @{(CLIENT_TYPES)}) . ']',
	writer => '_set_client_type',
	default => TYPE_NONE,
	init_arg => undef,
);

has 'stream' => (
	is => 'ro',
	isa => "InstanceOf['IO::Async::Stream']",
	required => 1,
);

with qw(PCRD::Role::HasOwner);

has '+owner' => (
	isa => "InstanceOf['PCRD::Listener']",
	required => 1,
);

sub BUILD
{
	my ($self, $args) = @_;
	weaken $self;

	$self->stream->configure(
		on_read => sub {
			$self->handle_message(@_);
			return 0;
		},
		on_closed => sub {
			$self->owner->unregister_stream($self);
		},
	);
}

sub send
{
	my ($self, @parts) = @_;

	$self->stream->write(PCRD::Protocol::message(@parts));
}

sub send_status
{
	my ($self, $success, @parts) = @_;

	my $message = $success
		? PCRD::Protocol::message_success(@parts)
		: PCRD::Protocol::message_error(@parts)
		;

	$self->stream->write($message);
}

sub handle_message
{
	my ($self, $stream, $buffref, $eof) = @_;

	my $type = $self->_client_type;
	if ($type == TYPE_NONE) {
		return $self->_handle_handshake($buffref);
	}
	elsif ($type == TYPE_QUERY) {
		return $self->_handle_query($buffref);
	}
	elsif ($type == TYPE_USER_AGENT) {
		return $self->_handle_user_agent($buffref);
	}
}

sub _handle_handshake
{
	my ($self, $buffref) = @_;

	while (my $handshake = PCRD::Protocol::extract_handshake_message($buffref)) {
		if ($handshake eq 'user_agent') {
			say 'new user agent';
			$self->_set_client_type(TYPE_USER_AGENT);
			$self->owner->register_user_agent($self);
		}
		elsif ($handshake eq 'query') {
			say 'new query client';
			$self->_set_client_type(TYPE_QUERY);
		}
		else {
			$self->send_status(!!0, "unknown handshake $handshake");
		}
	}
}

sub _handle_query
{
	my ($self, $buffref) = @_;
	my $write = sub {
		say "< $_[1]";
		$self->send_status(@_);
	};

	while (my @parts = PCRD::Protocol::extract_message($buffref, 4)) {
		say '> ' . join ' : ', @parts;

		my ($module, $feature_name, $action, $value) = @parts;
		my $modules = $self->owner->owner->modules;

		if (!$modules->{$module}) {
			$write->(!!0, "no module '$module'");
			next;
		}

		my $feature = $modules->{$module}->features->{$feature_name};
		if (!$feature) {
			$write->(!!0, "module '$module' does not have feature '$feature_name'");
			next;
		}

		if (!$feature->provides($action)) {
			$write->(!!0, "feature '$feature_name' from module '$module' does not provide action '$action'");
			next;
		}

		my $result;
		my $ex = PCRD::Util::try {
			$result = $feature->execute($action, $value);
		};

		if ($ex) {
			$ex =~ s/\n//g;
			$write->(!!0, $ex);
			next;
		}

		$result->on_ready(sub {
			$write->(!!1, $result->get);
		});
	}
}

sub _handle_user_agent
{
	my ($self, $buffref) = @_;

	my $futures = $self->owner->agent_handlers;
	while (my @parts = PCRD::Protocol::extract_message($buffref)) {
		my ($status, $id, @result) = @parts;

		if (!$futures->{$id}) {
			warn "agent malfunction: unknown id $id";
			next;
		}

		my $future = delete $futures->{$id};
		if (PCRD::Protocol::status_to_bool($status)) {
			$future->done(@result);
		}
		else {
			$future->fail(@result);
		}
	}
}

1;

