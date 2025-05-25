requires 'IO::Async';

on 'develop' => sub {
	requires 'Mite';
};

on 'test' => sub {
	requires 'Test2::V0';
};

