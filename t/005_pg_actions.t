use Test::More qw/no_plan/;
use Test::Exception;
use File::Spec::Functions;
use Module::Build;
use Class::MOP;
use Try::Tiny;
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
    dist_author        => 'Pataka'
);

SKIP: {
    my ( $pg, $mb_chado );
    try {
        Class::MOP::load_class('Test::postgresql');
    }
    catch {
        skip 'Test::postgresql is not installed';
    };

    subtest 'Module::Build::Chado with postgresql backend' => sub {
        use_ok('Module::Build::Chado');
        $pg       = Test::postgresql->new;
        $mb_chado = Module::Build::Chado->new(%opt);
        $mb_chado->dsn( $pg->dsn );

        subtest 'action deploy_schema' => sub {
            lives_ok { $mb_chado->ACTION_deploy_schema } 'should run';
            is( $mb_chado->feature('is_schema_loaded'),
                1, 'should have set the schema loaded flag' );

            subtest 'instantiate a database schema' => sub {
                my $dbh = $mb_chado->_handler->dbh;
                my ( $sth, $ary_ref );
                lives_ok {
                    $sth = $dbh->table_info( undef, undef, '%feature%',
                        'TABLE' );
                    $ary_ref = $dbh->selectcol_arrayref( $sth,
                        { Columns => [3] } );
                }
                'should retrieve tables';
                is( scalar @$ary_ref, 32, 'should have 32 table names' );
                is( ( all {/feature/i} @$ary_ref ),
                    1, 'should match table names with feature' );
            };
        };

        subtest 'action load_fixture' => sub {
            lives_ok { $mb_chado->ACTION_load_fixture } 'should run';
            my $bcs       = $mb_chado->_handler->schema;
            my $org_count = $bcs->resultset('Organism::Organism')->count;
            my $rel_count = $bcs->resultset('Cv::Cvterm')
                ->count( { 'cv.name' => 'relationship' }, { join => 'cv' } );
            my $so_count = $bcs->resultset('Cv::Cvterm')
                ->count( { 'cv.name' => 'sequence' }, { join => 'cv' } );
            cmp_ok( $rel_count, '==', 26,
                'should populate relationship ontology' );
            cmp_ok( $so_count, '==', 286,
                'should have loaded 286 sequence ontology terms' );
            cmp_ok( $org_count, '==', 12, 'should have loaded 12 organisms' );
        };
    };

    subtest 'action prune_fixture' => sub {
        lives_ok { $mb_chado->ACTION_prune_fixture } 'should run';

        my $bcs       = $mb_chado->_handler->schema;
        my $org_count = $bcs->resultset('Organism::Organism')->count;
        my $rel_count = $bcs->resultset('Cv::Cvterm')
            ->count( { 'cv.name' => 'relationship' }, { join => 'cv' } );
        my $so_count = $bcs->resultset('Cv::Cvterm')->count(
            {         'cv.name' => $mb_chado->prepend_namespace
                    . $mb_chado->_handler->loader_tag
                    . '-sequence'
            },
            { join => 'cv' }
        );

        cmp_ok( $rel_count, '==', 0,
            'should have deleted relationship ontology' );
        cmp_ok( $so_count, '==', 0, 'should have deleted sequence ontology' );
        cmp_ok( $org_count, '==', 0, 'should have deleted organisms' );

        subtest 'sustains the database schema' => sub {
            my $dbh = $mb_chado->_handler->dbh;
            my ( $sth, $ary_ref );
            lives_ok {
                $sth = $dbh->table_info( undef, undef, '%feature%', 'TABLE' );
                $ary_ref
                    = $dbh->selectcol_arrayref( $sth, { Columns => [3] } );
            }
            'should retrieve tables';
            is( scalar @$ary_ref, 32, 'should have 32 table names' );
        };

    };

    subtest 'action drop_schema' => sub {
        lives_ok { $mb_chado->ACTION_drop_schema } 'should run';
        my $dbh = $mb_chado->_handler->dbh;
        my ( $sth, $ary_ref );
        lives_ok {
            $sth = $dbh->table_info( undef, undef, 'feature%', 'TABLE' );
            $ary_ref = $dbh->selectcol_arrayref( $sth, { Columns => [3] } );
        }
        'should not retrieve tables';
        is( scalar @$ary_ref, 0, 'should not have any table name' );
    };

    if ( my $handler = $mb_chado->_handler ) {
        $handler->dbh->disconnect;
        $handler->dbh_withcommit->disconnect;
        $handler->super_dbh->disconnect;
    }
    undef $pg;
}

