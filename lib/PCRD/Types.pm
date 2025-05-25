package PCRD::Types;

use v5.14;
use warnings;
use Type::Library -base;
use Types::Standard qw(HashRef Str);

my $feature_mode = __PACKAGE__->add_type(
	name => 'PCRDFeatureMode',
	parent => HashRef,
);

$feature_mode->coercion->add_type_coercions(
	Str, q{ +{map { $_ => 1 } split //} },
);

__PACKAGE__->meta->make_immutable;

