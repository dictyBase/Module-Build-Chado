package Module::Build::Chado;
use strict;
use feature qw/say/;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;
use File::Temp;
use Class::MOP;
use DBI;
use Carp;
use File::Path qw/make_path/;
use Data::Dumper;
use IO::File;
use base qw/Module::Build/;

__PACKAGE__->add_property( 'dbic_config_file' => 'schema.pl' );
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
__PACKAGE__->add_property('schema');
__PACKAGE__->add_property( 'test_debug' => 0 );

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
    say "running setup" if $self->test_debug;

    return if $self->config('setup_done');

    my ( $scheme, $driver, $attr_str, $attr_hash, $driver_dsn )
        = DBI->parse_dsn( $self->dsn )
        or croak "cannot parse dbi dsn";
    $self->driver_dsn($driver_dsn);
    if ( !$self->ddl ) {
        my $ddl = catfile( module_dir('Module::Build::Chado'),
            'chado.' . lc $driver );
        $self->ddl($ddl);
    }

    $self->superuser( $self->user )         if !$self->superuser;
    $self->superpassword( $self->password ) if !$self->superpassword;

    my $db_class = 'Module::Build::Chado::' . ucfirst lc $driver;
    Class::MOP::load_class($db_class);
    my $chado = $db_class->new( module_builder => $self );
    $self->_handler($chado);
    $self->schema( $chado->schema );
    $self->config( 'setup_done', 1 );

    say "done with setup" if $self->test_debug;
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
    if ( !$self->feature('is_db_created') ) {
        $self->_handler->create_db;
        $self->feature( 'is_db_created' => 1 );
        say "created database" if $self->test_debug;
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
    if ( !$self->feature('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->feature( 'is_schema_loaded' => 1 );
        say "loaded schema" if $self->test_debug;
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
    $self->feature( 'is_db_created' => 1 );
    if ( !$self->feature('is_schema_loaded') ) {
        $self->_handler->deploy_schema;
        $self->feature( 'is_schema_loaded' => 1 );
        say "loaded schema" if $self->test_debug;
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
    return if $self->feature('is_fixture_loaded');

    if ( $self->can('before_all_fixtures') ) {
        $self->before_all_fixtures;
    }

    $self->depends_on('deploy_schema');
    $self->_handler->load_organism;
    $self->_handler->load_rel;
    $self->_handler->load_so;

    if ( $self->can('after_all_fixtures') ) {
        $self->after_all_fixtures;
    }

    $self->feature( 'is_fixture_loaded' => 1 );
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

=cut

sub ACTION_unload_fixture {
    my ($self) = @_;
    if ( $self->feature('is_fixture_loaded') ) {
        $self->depends_on('setup');
        $self->_handler->$_ for qw/unload_rel unload_so unload_organism/;
        $self->feature( 'is_fixture_loaded' => 0 );
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
    $self->feature( 'is_fixture_loaded' => 0 );
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

    ##cleanup all the setup values if any
    for my $name ( @{ $self->_config_keys } ) {
        say "cleaning $name" if $self->test_debug;
        $self->feature( $name => 0 );
    }
    $self->depends_on('drop_schema');
    $self->depends_on('deploy_schema');
    $self->depends_on('load_fixture');
    $self->depends_on('create_config');
    $self->recursive_test_files(1);
    $self->SUPER::ACTION_test(@_);
    $self->depends_on('drop_schema');
    $self->depends_on('delete_config');
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
        say "cleaning $name\n" if $self->test_debug;
        $self->feature( $name => 0 );
    }

    say "dropped the database\n" if $self->test_debug;
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
    $self->feature( 'is_fixture_loaded' => 0 );
    $self->feature( 'is_schema_loaded'  => 0 );
    say "dropped the schema\n" if $self->test_debug;
}

sub ACTION_create_config {
    my ($self) = @_;
    $self->depends_on('setup');
    my $base_path = catdir( $self->base_dir, 't', 'etc' );
    my $config_file = catfile( $base_path, $self->dbic_config_file );
    make_path($base_path);

    unlink $config_file if -e $config_file;
    my %connect_hash = $self->connect_hash;
    $connect_hash{dbi_attributes}->{AutoCommit} = 1;
    my $connect_info
        = [ @connect_hash{qw/dsn user password dbi_attributes/} ];

    my $config_hash = {
        'schema_class' => 'Bio::Chado::Schema',
        'keep_db'      => 1,
        'deploy_db'    => 0,
        'connect_info' => $connect_info,
        'resultsets'   => [
            'Cv::Cv',     'Organism::Organism',
            'Cv::Cvterm', 'Sequence::Feature', 'General::Db', 
            'General::Dbxref'
        ]
    };
    my $output = IO::File->new( $config_file, 'w' )
        or die "cannot open file:$!";
    $output->say( Dumper $config_hash);
    $output->close;
}

sub ACTION_delete_config {
    my ($self) = @_;
    my $config_file
        = catfile( $self->base_dir, 't', 'etc', $self->dbic_config_file );
    unlink $config_file if -e $config_file;
}

1;

# ABSTRACT: Build,configure and test chado database backed modules and applications

=head1 SYNOPSIS

=head3 Write build script(Build.PL) for your module or web application:

   use Module::Build::Chado;

   my $build = Module::Build::Chado->new(
                 module_name => 'MyChadoApp', 
                 license => 'perl', 
                 dist_abstract => 'My chado module'
                 dist_version => '1.0'

   );

  $build->create_build_script;


=head3 Then from the command line:

  perl Build.PL && ./Build test(default is a temporary SQLite database)

It will deploy chado schema in a SQLite database, load fixtures and run all tests)


=head3 In each of the test file(.t) access the schema(Bio::Chado::Schema) object

   use Module::Build::Chado;

   my $schema = Module::Build::Chado->current->schema;

   #do something with it ....

   $schema->resultset('Organism::Organism')->....

=head3 Use for other database backend

B<PostgreSQL>

  ./Build test --dsn "dbi:Pg:dbname=mychado" --user tucker --password booze

B<Oracle>

   ./Build test --dsn "dbi:Oracle:sid=myoracle" --user tucker --password hammer


=head1 DESCRIPTION

This is subclass of L<Module::Build> to configure,  build and test
L<chado|http://gmod.org/wiki/Chado> database backed
perl modules and applications. During the B</Build test>  testing phase it loads some
default fixtures which can be accessed in every test(.t) file using standard
L<DBIx::Class> API.

=head2 Default fixtures loaded

=over

=item  List of organisms

Look at the organism.yaml in the shared folder

=item Relationship ontology

OBO relationship types, available here
L<http://bioportal.bioontology.org/ontologies/1042>. 

=item Sequence ontology

Sequence types and features,  available here
L<http://bioportal.bioontology.org/ontologies/1109>

=back


=head2 Accessing fixtures data in test(.t) files

=over

=item Get a L<Bio::Chado::Schema> aka L<DBIx::Class> object

my $schema = Module::Build->current->schema;

isa_ok($schema, 'Bio::Chado::Schema');

=item Access them using L<DBIx::Class> API

  my $row = $schema->resultset('Organism::Organism')->find({species => 'Homo',  genus =>
'sapiens'});

  my $resultset = $schema->resultset('Organism::Organism')->search({});

  my $relonto = $schema->resultset('Cv::Cv')->find({'name' => 'relationship'});

  my $seqonto = $schema->resultset('Cv::Cv')->find({'name' => 'sequence'});

  my $cvterm_rs = $seqonto->cvterms;
  
  while(my $cvterm = $cvterm_rs->next) {
    .....
  }

  You probably will not be accessing them too often,  but mostly needed to load other test
  fixtures.

=back

=head2 Loading custom fixtures

=over 

=item *

Create your own subclass and implement either or both of two methods
B<before_all_fixtures> and B<after_all_fixtures>

=over

=item before_all_fixtures

This code will run before any fixture is loaded

=item after_all_fixtures

This code will run after organism data, relationship and sequence ontologies are loaded

=back

   package MyBuilder;
   use base qw/Module::Build::Chado/;

   sub before_all_fixtures {
      my ($self) = @_;
   }

   sub before_all_fixtures {
      my ($self) = @_;
   }

=item *

All the attributes and methods of B<Module::Build> and B<Module::Build::Chado> L<API>
become available through I<$self>.
 
=back


=head1 API

=attr schema

A L<Bio::Chado::Schema> object.

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
