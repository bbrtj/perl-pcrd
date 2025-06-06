package PCRD::Types;

use v5.14;
use warnings;
use Type::Library -base;
use Types::Standard qw(HashRef ArrayRef Str);

my $feature_mode = __PACKAGE__->add_type(
	name => 'PCRDFeatureMode',
	parent => HashRef,
);

$feature_mode->coercion->add_type_coercions(
	Str, q{ +{map { $_ => 1 } split //} },
);

my $dependencies = __PACKAGE__->add_type(
	name => 'PCRDDependencies',
	parent => HashRef,
);

$dependencies->coercion->add_type_coercions(
	ArrayRef, q{ +{map { $_ => undef } @$_} },
);

__PACKAGE__->meta->make_immutable;

