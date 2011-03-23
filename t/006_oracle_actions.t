use Test::More qw/no_plan/;
use Test::Exception;
use File::Spec::Functions;
use Module::Build;
use Class::MOP;
use Try::Tiny;
use List::MoreUtils qw/all uniq/;

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
    my $mb_chado;
    if (    ( not defined $ENV{ORACLE_DSN} )
        and ( not defined $ENV{ORACLE_USERID} ) )
    {
        skip "ORACLE_DSN and ORACLE_USERID env variables are not set";
    }

    subtest 'Module::Build::Chado with oracle backend' => sub {
        my ( $user, $pass ) = split /\//, $ENV{ORACLE_USERID};

        use_ok('Module::Build::Chado');

        $mb_chado = Module::Build::Chado->new(%opt);
        $mb_chado->dsn( $ENV{ORACLE_DSN} );
        $mb_chado->user($user);
        $mb_chado->password($pass);

        subtest 'action deploy_schema' => sub {
            lives_ok { $mb_chado->ACTION_deploy_schema } 'should run';
            is( $mb_chado->config('is_schema_loaded'),
                1, 'should have set the schema loaded flag' );

            subtest 'instantiate a database schema' => sub {
                my $dbh = $mb_chado->_handler->dbh;
                my ( $sth, @ary );
                lives_ok {
                    $sth = $dbh->table_info( undef, undef, 'FEATURE%',
                        'TABLE' );
                    @ary = uniq @{ $dbh->selectcol_arrayref( $sth,
                            { Columns => [3] } ) };
                }
                'should retrieve tables';
                is( scalar @ary, 26, 'should have 26 table names' );
                is( ( all {/feature/i} @ary ),
                    1, 'should match table names with feature' );
            };
        };

        subtest 'action load_fixture' => sub {
            lives_ok { $mb_chado->ACTION_load_fixture } 'should run';
            my $bcs       = $mb_chado->_handler->schema;
            my $org_count = $bcs->resultset('Organism::Organism')->count;
            my $rel_count = $bcs->resultset('Cv::Cvterm')->count(
                {         'cv.name' => $mb_chado->prepend_namespace
                        . $mb_chado->loader
                        . '-relationship'
                },
                { join => 'cv' }
            );
            my $so_count = $bcs->resultset('Cv::Cvterm')->count(
                {         'cv.name' => $mb_chado->prepend_namespace
                        . $mb_chado->loader
                        . '-sequence'
                },
                { join => 'cv' }
            );
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
        my $rel_count = $bcs->resultset('Cv::Cvterm')->count(
            {         'cv.name' => $mb_chado->prepend_namespace
                    . $mb_chado->loader
                    . '-relationship'
            },
            { join => 'cv' }
        );
        my $so_count = $bcs->resultset('Cv::Cvterm')->count(
            {         'cv.name' => $mb_chado->prepend_namespace
                    . $mb_chado->loader
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
            my ( $sth, @ary );
            lives_ok {
                $sth = $dbh->table_info( undef, undef, 'FEATURE%', 'TABLE' );
                @ary = uniq @{ $dbh->selectcol_arrayref( $sth,
                        { Columns => [3] } ) };
            }
            'should retrieve tables';
            is( scalar @ary, 26, 'should have 26 table names' );
        };

    };

    subtest 'action drop_schema' => sub {
        lives_ok { $mb_chado->ACTION_drop_schema } 'should run';
        my $dbh = $mb_chado->_handler->dbh;
        my ( $sth, @ary );
        lives_ok {
            $sth = $dbh->table_info( undef, undef, 'FEATURE%', 'TABLE' );
            @ary
                = uniq @{ $dbh->selectcol_arrayref( $sth, { Columns => [3] } )
                };
        }
        'should not retrieve tables';
        is( scalar @ary, 0, 'should not have any table name' );
    };

    if ( my $handler = $mb_chado->_handler ) {
        $handler->dbh->disconnect;
        $handler->dbh_withcommit->disconnect;
    }
}
