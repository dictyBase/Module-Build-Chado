use Test::More qw/no_plan/;
use Test::Exception;
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
    dist_author        => 'Pataka'
);

use_ok('Module::Build::Chado');

subtest 'attributes of Module::Build::Chado' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    isa_ok( $mb_chado, 'Module::Build::Chado' );
    can_ok(
        $mb_chado,
        qw/dsn _config_keys organism_fixture so_fixture rel_fixture
            prepend_namespace _conf_class ddl user password superuser superpassword attr
            loader _handler/
    );

    subtest 'default value of attributes' => sub {
        like( $mb_chado->dsn, qr/SQLite/, 'dsn should match SQLite' );
        is( reftype $mb_chado->_config_keys,
            ARRAY,
            '_config_keys should return an array reference'
        );
        like( $mb_chado->organism_fixture, qr/organism/,
            'organism_fixture should match organism' );
        like( $mb_chado->so_fixture, qr/sequence/,
            'so_fixture should match sequence' );
        like( $mb_chado->rel_fixture, qr/relationship/,
            'rel_fixture should match relationship' );
        is( $mb_chado->prepend_namespace,
            'Module-Build-Chado-',
            'prepend_namespace should return Module-Build-Chado-' );
        is( $mb_chado->_conf_class,
            'Module::Build::Chado::ConfigData',
            '_conf_class should return Module::Build::Chado::ConfigData'
        );
        is( $mb_chado->loader,       'bcs', 'loader should return bcs' );
        is( reftype $mb_chado->attr, HASH,  'attr should return a HASH' );
    };
};

subtest 'Module::Build::Chado has' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    can_ok(
        $mb_chado, qw/connect_hash connect_info ACTION_setup ACTION_create
            ACTION_deploy ACTION_deploy_schema ACTION_load_organism ACTION_load_rel ACTION_load_so
            ACTION_load_fixture ACTION_unload_rel ACTION_unload_organism ACTION_unload_so
            ACTION_unload_fixture ACTION_prune_fixture/
    );

    subtest 'connect_hash method' => sub {
        my %connect_hash = $mb_chado->connect_hash;
        is( defined $connect_hash{dsn},  1, 'should have a dsn key' );
        is( defined $connect_hash{attr}, 1, 'should have a attr key' );
        isnt( exists $connect_hash{user}, 1, 'should not have a user key' );
        isnt( exists $connect_hash{password},
            1, 'should not have a password key' );
        like( $connect_hash{dsn}, qr/dbi:SQLite/,
            'dsn key should match SQLite' );
        is_deeply(
            $connect_hash{attr},
            { AutoCommit => 1 },
            'attr key should return hash'
        );
    };

    subtest 'connect_info method' => sub {
        my @info = $mb_chado->connect_info;
        like( $info[0], qr/dbi:SQLite:dbname=\S+/,
            'first element should match the dsn' );
        is_deeply(
            $info[-1],
            { AutoCommit => 1 },
            'last element should contain the extra attribute'
        );

    };
};
