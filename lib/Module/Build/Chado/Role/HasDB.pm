package Module::Build::Chado::Role::HasDB;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Moose::Util qw/apply_all_roles/;

# Module implementation
#

requires 'create_db', 'drop_db', 'dbh', 'connection_info';
requires 'deploy_schema', 'prune_fixture', 'drop_schema';
requires 'dbi_attributes';

has 'module_builder' => (
    is        => 'rw',
    isa       => 'Module::Build',
    predicate => 'has_module_builder',
    trigger   => \&_setup_loader,
    handles   => {
        dsn           => 'dsn',
        user          => 'user',
        password      => 'password',
        ddl           => 'ddl',
        superuser     => 'superuser',
        superpassword => 'superpassword',
        loader        => 'loader'

    }
);

sub _setup_loader {
    my ( $self, $builder ) = @_;
    return if !$builder;
    $self->meta->make_mutable;
    apply_all_roles( $self,
        'Module::Build::Chado::Role::Loader::'
            . ucfirst lc( $builder->loader ) );
    $self->meta->make_immutable;
}


1;    # Magic true value required at end of module

