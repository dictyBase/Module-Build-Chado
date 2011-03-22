use Test::More qw/no_plan/;
use Test::Exception;
use File::Spec::Functions;
use Module::Build;

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

subtest 'Module::Build::Chado action unload_organsim' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_organism } 'should run';
    lives_ok { $mb_chado->ACTION_unload_organism } 'should run';
    my $count
        = $mb_chado->_handler->schema->resultset('Organism::Organism')->count;
    cmp_ok( $count, '==', 0, 'should have deleted the organisms' );
};

subtest 'Module::Build::Chado action unload_rel' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_rel } 'should run';
    lives_ok { $mb_chado->ACTION_unload_rel } 'should run';
    my $bcs = $mb_chado->_handler->schema;
    my $count
        = $bcs->resultset('Cv::Cvterm')
        ->count( { 'cv.name' => $mb_chado->_handler->current_cv },
        { join => 'cv' } );
    cmp_ok( $count, '==', 0, 'should have deleted relationship ontology' );
};

subtest 'Module::Build::Chado action unload_so' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_so } 'should run';
    lives_ok { $mb_chado->ACTION_unload_so } 'should run';
    my $bcs = $mb_chado->_handler->schema;
    my $count
        = $bcs->resultset('Cv::Cvterm')
        ->count( { 'cv.name' => $mb_chado->_handler->current_cv },
        { join => 'cv' } );
    cmp_ok( $count, '==', 0, 'should have deleted sequence ontology' );
};

subtest 'Module::Build::Chado action unload_fixture' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_fixture } 'should run';
    lives_ok { $mb_chado->ACTION_unload_fixture } 'should run';
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
    cmp_ok( $so_count,  '==', 0, 'should have deleted sequence ontology' );
    cmp_ok( $org_count, '==', 0, 'should have deleted organisms' );
};

subtest 'Module::Build::Chado action prune_fixture' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_fixture } 'should run';
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
    cmp_ok( $so_count,  '==', 0, 'should have deleted sequence ontology' );
    cmp_ok( $org_count, '==', 0, 'should have deleted organisms' );

    subtest 'sustains the database schema' => sub {
        my $dbh = $mb_chado->_handler->dbh;
        my ( $sth, $ary_ref );
        lives_ok {
            $sth = $dbh->table_info( undef, undef, '%feature%', 'TABLE' );
            $ary_ref = $dbh->selectcol_arrayref( $sth, { Columns => [3] } );
        }
        'should retrieve tables';
        is( scalar @$ary_ref, 30, 'should have 30 table names' );
    };

};
