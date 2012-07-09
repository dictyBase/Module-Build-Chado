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

subtest 'Module::Build::Chado actions for creating and deleting config' =>
    sub {
    my $mb_chado    = Module::Build::Chado->new(%opt);
    my $config_file = catfile( $mb_chado->base_dir, 't', 'etc',
        $mb_chado->dbic_config_file );
    isnt( -e $config_file,
        1, 'should not have any config file before the action is run' );
    lives_ok { $mb_chado->ACTION_create_config } 'should run';
    is( -e $config_file,
        1, 'should have config file after the action is run' );
    lives_ok { $mb_chado->ACTION_delete_config } 'should run';
    isnt( -e $config_file,
        1, 'should not have any config file after delete action' );
    };

subtest
    'Moduld::Build::Chado integration with Test::DBIx::Class and organism fixture'
    => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_create_config } 'should run';
    lives_ok { $mb_chado->ACTION_load_organism } 'should run';
    use_ok('Test::DBIx::Class');
    ok ResultSet('Organism::Organism'),
        'should have organism in the database';
    cmp_ok( ResultSet('Organism::Organism')->count,
        '>', 0, 'should populate organism table' );
    cmp_ok( ResultSet('Organism::Organism')->count,
        '==', 12, 'should have 12 organisms' );
    lives_ok { $mb_chado->ACTION_delete_config } 'should run';

    };

subtest 'Module::Build::Chado action load_rel' => sub {
    my $mb_chado = Module::Build::Chado->new(%opt);
    lives_ok { $mb_chado->ACTION_create_config } 'should run';
    lives_ok { $mb_chado->ACTION_load_rel } 'should run';
    my $namespace = $mb_chado->_handler->ontology_namespace;
    use_ok('Test::DBIx::Class');
    ok ResultSet('Cv::Cvterm')
        ->search( { 'cv.name' => $namespace }, { join => 'cv' } ),
        'should populate relationship ontology';
    cmp_ok(
        ResultSet('Cv::Cvterm')
            ->search( { 'cv.name' => $namespace }, { join => 'cv' } ),
        '==', 26, 'should have 26 relationship ontology terms'
    );
    ok ResultSet('Cv::Cvterm')->find( { name => 'located_in' } ),  'should have cvterm located_in';
    lives_ok { $mb_chado->ACTION_delete_config } 'should run';
};
