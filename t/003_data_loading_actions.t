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
    cmp_ok( $count, '>',  0,  'should populate relation ontology' );
    cmp_ok( $count, '==', 26, 'should have loaded 25 cvterms' );
    is( $bcs->resultset('Cv::Cvterm')->count( { name => 'located_in' } ),
        1, 'should have loaded located_in cvterm' );
};
