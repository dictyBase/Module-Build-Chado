package Module::Build::Chado;
use strict;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;
use File::Temp;
use Class::MOP;
use DBI;
use Carp;
use parent qw/Module::Build/;

__PACKAGE__->add_property(
    'dsn',
    default => sub {
        my $file = tmpnam();
        return "dbi:SQLite:dbname=$file";
    }
);

__PACKAGE__->add_property(
    '_config_keys',
    [   qw/is_db_created is_schema_loaded setup_done
            is_fixture_loaded is_fixture_unloaded/
    ]
);

__PACKAGE__->add_property(
    'organism_fixture',
    default => sub {
        catfile( module_dir('Module::Build::Chado'), 'organism.yaml' );
    }
);

__PACKAGE__->add_property(
    'so_fixture',
    default => sub {
        catfile( module_dir('Module::Build::Chado'), 'sequence.obo_xml' );
    }
);

__PACKAGE__->add_property(
    'rel_fixture',
    default => sub {
        catfile( module_dir('Module::Build::Chado'), 'relationship.obo_xml' );
    }
);

__PACKAGE__->add_property( 'preprend_namespace',
    default => 'Module-Build-Chado-' );

__PACKAGE__->add_property( '_conf_class',
    default => 'Module::Build::Chado::ConfigData' );

__PACKAGE__->add_property('ddl');
__PACKAGE__->add_property('user');
__PACKAGE__->add_property('password');
__PACKAGE__->add_property('superuser');
__PACKAGE__->add_property( 'attr', default => sub { AutoCommit => 1 } );
__PACKAGE__->add_property('superpassword');
__PACKAGE__->add_property( 'loader', default => 'bcs' );
__PACKAGE__->add_property('_handler');

sub connect_hash {
    my $self = shift;
    my %hash;
    for my $prop (qw/dsn user password attr/) {
        $hash{$prop} = $self->$prop if $self->$prop;
    }
    return %hash;
}

sub connect_str {
    my $self = shift;
    my @array;
    for my $prop (qw/dsn user password attr/) {
        push @array, $self->$prop if $self->$prop;
    }
    return join( ',', @array );
}

sub ACTION_setup {
    my $self = shift;
    $self->depends_on('build');
    print "running setup\n" if $self->args('test_debug');

    Class::MOP::load_class('Module::Build::Chado::ConfigData');
    Class::MOP::load_class('Module::Build::Chado::Handler');

    return if $self->_conf_class->config('setup_done');

    my $chado = Module::Build::Chado::Handler->new;
    $chado->module_builder($self);
    for my $prop (qw/dsn user password superuser superpassword attr loader/) {
        $chado->$prop( $self->$prop ) if $self->$prop;
    }

    if ( $self->ddl ) {
        $chado->ddl( $self->ddl );
    }
    else {
        my ( $scheme, $driver ) = DBI->parse_dsn( $self->dsn )
            or croak "cannot parse dbi dsn";
        my $ddl = catfile( module_dir('Module::Build::Chado'), 'chado.' . lc $driver );
        $chado->ddl($ddl) if -e $ddl;
    }

    $self->_handler($chado);
    $self->config_data( 'setup_done' => 1 );
    print "done with setup\n" if $self->args('test_debug');
}

sub ACTION_create {
    my ($self) = @_;
    $self->depends_on('setup');
    if ( !$self->_conf_class->config('is_db_created') ) {
        $self->_handler->create_db;
        $self->config_data( 'is_db_created' => 1 );
        print "created database\n" if $self->args('test_debug');
    }
}

sub ACTION_deploy {
    my ($self) = @_;
    $self->depends_on('create');
    if ( !$self->_conf_class->config('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->config_data( 'is_schema_loaded' => 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

sub ACTION_deploy_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->config_data( 'is_db_created' => 1 );
    if ( !$self->_conf_class->config('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->config_data( 'is_schema_loaded' => 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

sub ACTION_load_organism {
    my ($self) = @_;
    $self->depends_on('deploy');
    $self->_handler->load_organism;
}

sub ACTION_load_rel {
    my ($self) = @_;
    $self->depends_on('deploy');
    $self->_handler->load_rel;
}

sub ACTION_load_so {
    my ($self) = @_;
    $self->depends_on('rel');
    $self->_handler->load_so;
}

sub ACTION_load_pub {
    my ($self) = @_;
    $self->depends_on('load_rel');
    $self->handler->load_pub;
}

sub ACTION_load_publication {
    my ($self) = @_;
    $self->depends_on('load_pub');
    $self->handler->load_journal_data;
}

sub ACTION_load_fixture {
    my ($self) = @_;
    $self->depends_on('deploy_schema');
    if ( !$self->conf_class->config('is_fixture_loaded') ) {
        $self->_handler->load_organism;
        $self->_handler->load_rel;
        $self->_handler->load_so;
        $self->config_data( 'is_fixture_loaded' => 1 );
        print "loaded fixture\n" if $self->args('test_debug');
    }
}

sub ACTION_unload_rel {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_rel;
}

sub ACTION_unload_pub {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_pub;
}

sub ACTION_unload_so {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_so;
}

sub ACTION_unload_organism {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_organism;
}

sub ACTION_unload_fixture {
    my ($self) = @_;
    if ( $self->_conf_class->config('is_fixture_loaded') ) {
        $self->depends_on($_) for qw/unload_rel unload_so unload_organism/;
        $self->config_data( 'is_fixture_loaded'   => 0 );
        $self->config_data( 'is_fixture_unloaded' => 1 );
    }
}

sub ACTION_prune_fixture {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->prune_fixture;
    $self->config_data( 'is_fixture_loaded'   => 0 );
    $self->config_data( 'is_fixture_unloaded' => 1 );
}

sub ACTION_test {
    my ($self) = @_;

    #cleanup all the setup values if any
    for my $name ( @{ $self->_config_keys } ) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->config_data( $name => 0 );
    }
    $self->depends_on('drop_schema');
    $self->depends_on('load_fixture');
    $self->recursive_test_files(1);
    $self->SUPER::ACTION_test(@_);
    $self->depends_on('drop_schema');
}

sub ACTION_drop {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->drop;

    #cleanup all the setup values if any
    for my $name ( @{ $self->_config_keys } ) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->config_data( $name => 0 );
    }
    print "dropped the database\n" if $self->args('test_debug');
}

sub ACTION_drop_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->drop_schema;
    $self->config_data( 'is_schema_loaded' => 0 );
}

1;

# ABSTRACT: Module::Build extension for Chado database
