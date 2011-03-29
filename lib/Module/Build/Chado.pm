package Module::Build::Chado;
use strict;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;
use File::Temp;
use Class::MOP;
use DBI;
use Carp;
use base qw/Module::Build/;

__PACKAGE__->add_property(
    'dsn',
    default => sub {
        my $file = tmpnam();
        return "dbi:SQLite:dbname=$file";
    }
);

__PACKAGE__->add_property(
    '_config_keys' => [
        qw/is_db_created is_schema_loaded setup_done
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
        catfile( module_dir('Module::Build::Chado'), 'sofa.obo_xml' );
    }
);

__PACKAGE__->add_property(
    'rel_fixture',
    default => sub {
        catfile( module_dir('Module::Build::Chado'), 'relationship.obo_xml' );
    }
);

__PACKAGE__->add_property( 'prepend_namespace' => 'Module-Build-Chado-' );
__PACKAGE__->add_property('driver_dsn');
__PACKAGE__->add_property('ddl');
__PACKAGE__->add_property('user');
__PACKAGE__->add_property('password');
__PACKAGE__->add_property('superuser');
__PACKAGE__->add_property('superpassword');
__PACKAGE__->add_property('_handler');

sub connect_hash {
    my ($self) = @_;
    $self->depends_on('setup');
    my %hash;
    for my $prop (qw/dsn user password/) {
        $hash{$prop} = $self->$prop if $self->$prop;
    }
    $hash{dbi_attributes} = $self->_handler->dbi_attributes;
    return %hash;
}

sub connect_info {
    my ($self) = @_;
    $self->depends_on('setup');
    return $self->_handler->connection_info;
}

=head2 Actions

=head3 setup

=begin comment

=head3 ACTION_setup

=end comment

Sets up the basic parameters for the build object and loads the specific backend class. It
is called by every other action. Override of calling it separately absolutely not
recommended.

=cut

sub ACTION_setup {
    my $self = shift;
    $self->depends_on('build');
    print "running setup\n" if $self->args('test_debug');

    return if $self->config('setup_done');

    my ( $scheme, $driver, $attr_str, $attr_hash, $driver_dsn )
        = DBI->parse_dsn( $self->dsn ) or croak "cannot parse dbi dsn";
    $self->driver_dsn($driver_dsn);
    if ( !$self->ddl ) {
        my $ddl = catfile( module_dir('Module::Build::Chado'),
            'chado.' . lc $driver );
        $self->ddl($ddl);
    }

    $self->superuser($self->user) if !$self->superuser;
    $self->superpassword($self->password) if !$self->superpassword;

    my $db_class = 'Module::Build::Chado::' . ucfirst lc $driver;
    Class::MOP::load_class($db_class);
    my $chado = $db_class->new( module_builder => $self );
    $self->_handler($chado);
    $self->config( 'setup_done', 1 );
    print "done with setup\n" if $self->args('test_debug');
}

=head3 create

=begin comment

=head3 ACTION_create

=end comment

Creates a database. However,  at this point it is not implemented for Postgresql and
Oracle backends. For that,  you need to use database specific client tools. For SQLite
backend the database is created when the schema is loaded.

=cut

sub ACTION_create {
    my ($self) = @_;
    $self->depends_on('setup');
    if ( !$self->config('is_db_created') ) {
        $self->_handler->create_db;
        $self->config( 'is_db_created', 1 );
        print "created database\n" if $self->args('test_debug');
    }
}

=head3 deploy

=begin comment

=head3 ACTION_deploy

=end comment

Deploy a chado database to the specified backend. Create action is implied.

=cut

sub ACTION_deploy {
    my ($self) = @_;
    $self->depends_on('create');
    if ( !$self->config('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->config( 'is_schema_loaded', 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

=head3 deploy_schema

=begin comment

=head3 ACTION_deploy_schema

=end comment

Deploy a chado database to the specified backend. Unlike the B<deploy> action,  create
action is not implied here. So,  except SQLite backend,  this action expects a database to
be created already.

=cut

sub ACTION_deploy_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->config( 'is_db_created', 1 );
    if ( !$self->config('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->config( 'is_schema_loaded', 1 );
        print "loaded schema\n" if $self->args('test_debug');
    }
}

=head3 load_organism

=begin comment

=head3 ACTION_load_organism

=end comment

Loads the organism fixture to the deployed chado schema. B<deploy_schema> action is
implied.

=cut

sub ACTION_load_organism {
    my ($self) = @_;
    $self->depends_on('deploy_schema');
    $self->_handler->load_organism;
}

=head3 load_rel

=begin comment

=head3 ACTION_load_rel

=end comment

Load the relationship ontology. B<deploy_schema> action is implied.

=cut

sub ACTION_load_rel {
    my ($self) = @_;
    $self->depends_on('deploy_schema');
    $self->_handler->load_rel;
}

=head3 load_so

=begin comment

=head3 ACTION_load_so

=end comment

Load the sequence ontology. B<load_rel> action is implied.

=cut

sub ACTION_load_so {
    my ($self) = @_;
    $self->depends_on('load_rel');
    $self->_handler->load_so;
}

=head3 load_fixture

=begin comment

=head3 ACTION_load_fixture

=end comment

Load all fixtures in the given order.

=over

=item organism

=item relationship ontology

=item sequence ontology

=back

B<deploy_schema> is implied.

=cut

sub ACTION_load_fixture {
    my ($self) = @_;
    $self->depends_on('deploy_schema');
    if ( !$self->config('is_fixture_loaded') ) {
        $self->_handler->load_organism;
        $self->_handler->load_rel;
        $self->_handler->load_so;
        $self->config( 'is_fixture_loaded', 1 );
        print "loaded fixture\n" if $self->args('test_debug');
    }
}

=head3 unload_rel

=begin comment

=head3 ACTION_unload_rel

=end comment

Deletes the relationship ontology.

=cut

sub ACTION_unload_rel {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_rel;
}

=head3 unload_so

=begin comment

=head3 ACTION_unload_so

=end comment

Deletes the sequence ontology.

=cut

sub ACTION_unload_so {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_so;
}

=head3 unload_organism

=begin comment

=head3 ACTION_unload_organism

=end comment

Deletes the organisms.

=cut

sub ACTION_unload_organism {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->unload_organism;
}

=head3 unload_fixture

=begin comment

=head3 ACTION_unload_fixture

=end comment

Delete all fixtures including organism,  relationship and sequence ontologies.
Currently implies running of B<unload_rel>,  B<unload_so> and B<unload_organism> actions. 

=cut

sub ACTION_unload_fixture {
    my ($self) = @_;
    if ( $self->config('is_fixture_loaded') ) {
        $self->depends_on($_) for qw/unload_rel unload_so unload_organism/;
        $self->config( 'is_fixture_loaded', 0 );
        $self->config_data( 'is_fixture_unloaded' => 1 );
    }
}

=head3 prune_fixture

=begin comment

=head3 ACTION_prune_fixture

=end comment

Delete all fixtures. However,  unlike running all the dependent unload_actions similar to
B<unload_fixture> it empties all the database tables. It runs a little bit faster than
B<unload_fixture>.

=cut

sub ACTION_prune_fixture {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->prune_fixture;
    $self->config( 'is_fixture_loaded',   0 );
    $self->config( 'is_fixture_unloaded', 1 );
}

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides the default B<Action_test> of L<Module::Build>. This action drop any existing
schema,  loads the fixture along with the schema,  runs all the tests and then drops the
schema.

=cut

sub ACTION_test {
    my ($self) = @_;

    #cleanup all the setup values if any
    for my $name ( @{ $self->_config_keys } ) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->config( $name ,  0 );
    }
    $self->depends_on('drop_schema');
    $self->depends_on('load_fixture');
    $self->recursive_test_files(1);
    $self->SUPER::ACTION_test(@_);
    $self->depends_on('drop_schema');
}

=head3 drop

=begin comment

=head3 ACTION_drop

=end comment

Drops the database. However,  except SQLite it is not implemented for Oracle and
Postgresql.

=cut

sub ACTION_drop {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->drop;

    #cleanup all the setup values if any
    for my $name ( @{ $self->_config_keys } ) {
        print "cleaning $name\n" if $self->args('test_debug');
        $self->config( $name , 0 );
    }
    print "dropped the database\n" if $self->args('test_debug');
}

=head3 drop_schema

=begin comment

=head3 ACTION_drop_schema

=end comment

Drops the database schema.

=cut

sub ACTION_drop_schema {
    my ($self) = @_;
    $self->depends_on('setup');
    $self->_handler->drop_schema;
    $self->config_data( 'is_schema_loaded' => 0 );
}

1;

# ABSTRACT: Build,configure and test chado database backed modules and applications

=head1 SYNOPSIS

In Build.PL:

use Module::Build::Chado;

my $build = Module::Build::Chado->new(
                 module_name => 'MyChadoApp', 
                 license => 'perl', 
                 dist_abstract => 'My chado module'
                 dist_version => '1.0'

);

$build->create_build_script;

On the command line:

perl Build.PL (default is a temporary SQLite database)

./Build test (deploy chado schema and load fixtures)

./Build test --dsn "dbi:Pg:dbname=mychado" --user tucker --password booze

./Build test --dsn "dbi:Oracle:sid=myoracle" --user tucker --password hammer

./Build deploy_schema (deploy a chado schema)

./Build load_fixture (load some standard fixtures)

./Build drop_schema


=head1 DESCRIPTION

This is subclass of L<Module::Build> to configure,  build and test
L<chado|http://gmod.org/wiki/Chado> database backed
perl modules and applications. It is based on L<Bio::Chado::Schema> and provides the
following additional features ...

=over

=item * 

Extra Module::Build properties and actions to deploy, load fixtures and run tests on a
chado database schema.

=item *

Support SQLite, Postgresql and Oracle backends.

=back


=attr dsn

Database connect string,  defaults to a temporary SQLite database.

=attr user

Database user,  not needed for SQLite backend.

=attr password

Database password,  not needed for SQLite backend.

=attr superuser

Database super user, in case the regular use do not have enough permissions for
manipulating the database schema. It defaults to the user attribute.

=attr superpassword

Similar concept as superuser

=attr ddl

DDL file for particular backend,  by default comes for SQLite,  Postgresql and Oracle.

=attr organism_fixuture

Fixture for loading organisms,  by default the distribution comes with a organism.yaml
file.

=attr rel_fixuture

Relation ontology file in obo_xml format. The distribution includes a relationship.obo_xml
file.

=attr so_fixuture

Sequence ontology file in obo_xml format. By default,  it includes sofa.obo_xml file.



=method connect_hash

Returns a hash with the following connection specific keys ...

=over

=item dsn

=item user

=item password

=item dbi_attributes

=back

=method connect_info

Returns an 4 elements array with connection arguments identical to L<DBI>'s B<connect>
method.
