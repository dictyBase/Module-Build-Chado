use Test::More qw/no_plan/;
use Test::Exception;
use Test::Moose;
use File::Spec::Functions;
use Module::Build;
use Scalar::Util qw/reftype/;
use List::MoreUtils qw/all/;

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
    does_ok( $mb_chado->_handler, 'Module::Build::Chado::Role::HasDB',
        'handler object should do the Module::Build::Chado::Role::HasDB role'
    );
    is( $mb_chado->feature('setup_done'), 1, 'should be completed' );
    isa_ok( $mb_chado->_handler->dbh, 'DBI::db' );
    isa_ok( $mb_chado->_handler->schema, 'Bio::Chado::Schema' );
};

subtest 'Module::Build::Chado has' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    subtest 'connect_hash method' => sub {
        my %connect_hash = $mb_chado->connect_hash;
        is( defined $connect_hash{dsn}, 1, 'should have a dsn key' );
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

subtest 'Module::Build::Chado action create' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_create } 'should run';
    is( $mb_chado->feature('setup_done'), 1,
        'should have set the setup flag' );
    is( $mb_chado->feature('is_db_created'),
        1, 'should have set the created flag' );
};

subtest 'Module::Build::Chado action deploy' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_deploy } 'should run';
    is( $mb_chado->feature('setup_done'), 1,
        'should have set the setup flag' );
    is( $mb_chado->feature('is_db_created'),
        1, 'should have set the created flag' );
    is( $mb_chado->feature('is_schema_loaded'),
        1, 'should have set the schema loaded flag' );
    subtest 'instantiate a database schema' => sub {
        my $dbh = $mb_chado->_handler->dbh;
        my ( $sth, $ary_ref );
        lives_ok {
            $sth = $dbh->table_info( undef, undef, '%feature%', 'TABLE' );
            $ary_ref = $dbh->selectcol_arrayref( $sth, { Columns => [3] } );
        }
        'should retrieve tables';
        is( scalar @$ary_ref, 30, 'should have 30 table names');
        is ((all {/feature/i} @$ary_ref),  1,  'should match table names with feature');

    };
};


