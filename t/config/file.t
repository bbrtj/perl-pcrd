use Test2::V0;
use PCRD::Config::File;

################################################################################
# This tests whether the file config works correctly
################################################################################

my $conf1 = PCRD::Config::File->new(filename => 't/config/conf1');
$conf1->load_config;
is $conf1->get_values, {
	a => {
		b => {
			c => 'd',
		}
	},
	b => 3,
	},
	'conf1 ok';

my $conf2 = PCRD::Config::File->new(filename => 't/config/conf2');
$conf2->load_config;
is $conf2->get_values, {
	a => 15,
	b => 16,
	ab => {
		ac => '16='
	},
	},
	'conf2 ok';

done_testing;

