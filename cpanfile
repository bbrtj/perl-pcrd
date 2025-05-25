requires 'IO::Async';

on 'development' => sub {
	requires 'Mite';
};

on 'test' => sub {
	requires 'Test2::V0';
};

