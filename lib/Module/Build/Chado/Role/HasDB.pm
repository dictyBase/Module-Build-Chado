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

has 'loader_namespace' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Module::Build::Chado::Role::Loader'
);

has 'loader_module' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Bcs'
);

has 'loader' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        my ($self) = @_;
        return $self->loader_namespace . '::' . $self->loader_module;
    }
);

has 'module_builder' => (
    is        => 'rw',
    isa       => 'Module::Build',
    predicate => 'has_module_builder',
    trigger   => \&_setup_loader,
);

sub _setup_loader {
    my ( $self, $builder ) = @_;
    return if !$builder;
    $self->meta->make_mutable;
    apply_all_roles( $self, $self->loader );
    $self->meta->make_immutable;
}

for my $name (
    qw/dsn user password ddl superuser
    superpassword driver_dsn/
    )
{
    has $name => (
        is      => 'rw',
        isa     => 'Maybe[Str]',
        default => sub {
            my $self = shift;
            $self->module_builder->$name;
        },
        lazy => 1
    );
}
1;    # Magic true value required at end of module

# ABSTRACT: Moose role provides an interface and to be consumed by database specific classes

=attr module_builder

Get/Set a L<Module::Build::Chado> object.

