package Module::Build::Chado::Role::HasDB;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Moose::Util qw/ensure_all_roles/;

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
    lazy => 1, 
    trigger => sub {
    	my ($self,  $value) = @_;
    	my @name = split /::/, $value;
    	$self->loader_module(pop @name);
    	$self->loader_namespace(join('::', @name));
    }, 
    default => sub {
        my ($self) = @_;
        return $self->loader_namespace . '::' . $self->loader_module;
    }
);

has 'loader_tag' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { return lc $_[0]->loader_module },
    lazy    => 1
);

has '_loader_stack' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [qw/Array/],
    handles => {
        extra_loaders        => 'elements',
        add_extra_loader     => 'push',
        _clear_extra_loaders => 'clear',
        extra_loader_count   => 'count'
    },
    lazy    => 1,
    default => sub { [] }
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
    ensure_all_roles( $self,
        $self->extra_loader_count
        ? ( $self->loader, $self->extra_loaders )
        : $self->loader );
    $self->meta->make_immutable;
}

sub inject_loader {
    my ( $self, $loader ) = @_;
    if ($loader) {
        $self->meta->make_mutable;
        ensure_all_roles( $self, $loader );
        $self->meta->make_immutable;
    }
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
B<Remember:> Setting this will trigger whatever L<moose roles|Moose::Role> are specified
by L<loader> and L<add_extra_loader> attributes. Adding additional roles should be done by
L<inject loader> method.

=attr loader

Name of L<moose role|Moose::Role> to be used as default loader. The default role is
L<Module::Build::Chado::Loader::BCS>

=attr add_extra_loader

Name of a addtional L<moose role|Moose::Role> to be used for loading fixture,  however use
this if before setting the L<module builder|module_builder> attribute.

=method inject_loader

Name of additonal L<moose role|Moose::Role> for loading fixuture,  however use this if the
L<module builder|module_builder> attribute is already set.

