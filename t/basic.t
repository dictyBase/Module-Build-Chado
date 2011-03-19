use Test::More qw/no_plan/;
use Test::Exception;
use File::Spec::Functions;

my $build = Module::Build->current;
my $dir = catdir( $build->base_dir, 't', 'lib', 'mydb' );

my %opt = (
    module_name        => 'MyDB',
    license            => 'perl',
    create_readme      => 1,
    dist_abstract      => 'Module for testing module',
    configure_requires => { 'Module::Build' => '' },
    dist_version       => '0.001',
    dist_author        => 'Pataka'
);

my $mb_chado = new_ok( 'Module::Build::Chado' => %opt );
can_ok(
    $mb_chado,
    qw/dsn ddl_dir fixture_dir organism_fixture so_fixture rel_fixture
        prepend_namespace ddl user password loader _handler/,
    'It has the given methods'
);
