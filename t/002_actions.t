use Test::More qw/no_plan/;
use Test::Exception;
use Test::Moose;
use File::Spec::Functions;
use Module::Build;
use Scalar::Util qw/reftype/;

my $build = Module::Build->current;
my $dir = catdir( $build->base_dir, 't', 'lib', 'mydb' );
chdir $dir or die "cannot change dir to $dir\n";
my %opt = (
    module_name        => 'MyDB',
    license            => 'perl',
    create_readme      => 1,
    dist_abstract      => 'Module for testing module',
    configure_requires => { 'Module::Build' => '' },
    dist_version       => '0.001',
    dist_author        => 'Pataka',
    quiet              => 1
);

use_ok('Module::Build::Chado');

subtest 'Module::Build::Chado action setup' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_setup } 'should run';
    does_ok(
        $mb_chado->_handler, 'Module::Build::Chado::Role::HasDB',
        'handler object should do the Module::Build::Chado::Role::HasDB role'
    );
    is( $mb_chado->config('setup_done'), 1, 'should be completed' );
};

subtest 'Module::Build::Chado has' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    subtest 'connect_hash method' => sub {
        my %connect_hash = $mb_chado->connect_hash;
        is( defined $connect_hash{dsn},  1, 'should have a dsn key' );
        is( defined $connect_hash{dbi_attributes},
            1, 'should have a dbi_attributes key' );
        isnt( exists $connect_hash{user}, 1, 'should not have a user key' );
        isnt( exists $connect_hash{password},
            1, 'should not have a password key' );
        like( $connect_hash{dsn}, qr/dbi:SQLite/,
            'dsn key should match SQLite' );
    };

    subtest 'connect_info method' => sub {
        my @info = $mb_chado->connect_info;
        like( $info[0], qr/dbi:SQLite:dbname=\S+/,
            'first element should match the dsn' );
        is( reftype $info[-1],
            HASH, 'last element should return a HASH reference' );

        my $attr = $info[-1];
        is( exists $attr->{AutoCommit},
            1, 'HASH reference should have AutoCommit key' );

    };

};
