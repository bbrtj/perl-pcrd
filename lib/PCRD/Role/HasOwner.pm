package PCRD::Role::HasOwner;

use v5.14;
use warnings;

use PCRD::Mite -role;

has 'owner' => (
	is => 'ro',
	isa => "InstanceOf['PCRD::ConfiguredObject']",
	predicate => 'has_owner',
	weak_ref => 1,
);

1;

