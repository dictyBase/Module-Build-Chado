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
    dist_author        => 'Pataka',
    quiet              => 1
);

use_ok('Module::Build::Chado');

subtest 'Module::Build::Chado action load_organsim' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_organism } 'should run';
    my $count
        = $mb_chado->_handler->schema->resultset('Organism::Organism')->count;
    cmp_ok( $count, '>',  0,  'should populate organism table' );
    cmp_ok( $count, '==', 12, 'should have 12 organisms' );
};

subtest 'Module::Build::Chado action load_rel' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_rel } 'should run';
    my $bcs = $mb_chado->_handler->schema;
    my $count
        = $bcs->resultset('Cv::Cvterm')
        ->count( { 'cv.name' => $mb_chado->_handler->current_cv },
        { join => 'cv' } );
    cmp_ok( $count, '>', 0, 'should populate relationship ontology' );
    cmp_ok( $count, '==', 26,
        'should have loaded relationship ontology terms' );
    is( $bcs->resultset('Cv::Cvterm')->count( { name => 'located_in' } ),
        1, 'should have loaded located_in cvterm' );
};

subtest 'Module::Build::Chado action load_so' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_so } 'should run';
    my $bcs       = $mb_chado->_handler->schema;
    my $rel_count = $bcs->resultset('Cv::Cvterm')->count(
        {         'cv.name' => $mb_chado->prepend_namespace
                . $mb_chado->loader
                . '-relationship'
        },
        { join => 'cv' }
    );
    my $count
        = $bcs->resultset('Cv::Cvterm')
        ->count( { 'cv.name' => $mb_chado->_handler->current_cv },
        { join => 'cv' } );
    cmp_ok( $rel_count, '==', 26, 'should populate relationship ontology' );
    cmp_ok( $count,     '>',  0,  'should populate sequence ontology' );
    cmp_ok( $count, '==', 286,
        'should have loaded 286 sequence ontology terms' );
    is( $bcs->resultset('Cv::Cvterm')->count(
            {   'me.name' => {
                    -in => [
                        qw/polypeptide gene
                            chromosome/
                    ]
                },
                'cv.name' => $mb_chado->_handler->current_cv
            },
            { join => 'cv' }
        ),
        3,
        'should have loaded gene chromosome and polypeptide sequence ontology terms'
    );
};

subtest 'Module::Build::Chado action load_fixture' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_load_fixture } 'should run';
    my $bcs       = $mb_chado->_handler->schema;
	my $org_count
        = $bcs->resultset('Organism::Organism')->count;
    my $rel_count = $bcs->resultset('Cv::Cvterm')->count(
        {         'cv.name' => $mb_chado->prepend_namespace
                . $mb_chado->loader
                . '-relationship'
        },
        { join => 'cv' }
    );
    my $so_count
        = $bcs->resultset('Cv::Cvterm')
        ->count( { 'cv.name' => $mb_chado->prepend_namespace.$mb_chado->loader.'-sequence' },
        { join => 'cv' } );
    cmp_ok( $rel_count, '==', 26, 'should populate relationship ontology' );
    cmp_ok( $so_count, '==', 286,
        'should have loaded 286 sequence ontology terms' );
    cmp_ok( $org_count, '==', 12, 'should have loaded 12 organisms' );
};
