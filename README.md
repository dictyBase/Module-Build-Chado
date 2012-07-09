# NAME

Module::Build::Chado - Build,configure and test chado database backed modules and applications

# VERSION

version 0.0011

# SYNOPSIS

### Write build script(Build.PL) for your module or web application:

    use Module::Build::Chado;

    my $build = Module::Build::Chado->new(
                  module_name => 'MyChadoApp', 
                  license => 'perl', 
                  dist_abstract => 'My chado module'
                  dist_version => '1.0'

    );

    $build->create_build_script;

### Then from the command line:

    perl Build.PL && ./Build test(default is a temporary SQLite database)

It will deploy chado schema in a SQLite database, load fixtures and run all tests)

### In each of the test file(.t) access the schema(Bio::Chado::Schema) object

    use Module::Build::Chado;

    my $schema = Module::Build::Chado->current->schema;

    #do something with it ....

    $schema->resultset('Organism::Organism')->....

### Use for other database backend

__PostgreSQL__

    ./Build test --dsn "dbi:Pg:dbname=mychado" --user tucker --password booze

__Oracle__

    ./Build test --dsn "dbi:Oracle:sid=myoracle" --user tucker --password hammer

# DESCRIPTION

This is subclass of [Module::Build](http://search.cpan.org/perldoc?Module::Build) to configure,  build and test
[chado](http://search.cpan.org/perldoc?http:#/gmod.org/wiki/Chado) database backed
perl modules and applications. During the __/Build test__  testing phase it loads some
default fixtures which can be accessed in every test(.t) file using standard
[DBIx::Class](http://search.cpan.org/perldoc?DBIx::Class) API.

## Default fixtures loaded

- List of organisms

Look at the organism.yaml in the shared folder

- Relationship ontology

OBO relationship types, available here
[http://bioportal.bioontology.org/ontologies/1042](http://bioportal.bioontology.org/ontologies/1042). 

- Sequence ontology

Sequence types and features,  available here
[http://bioportal.bioontology.org/ontologies/1109](http://bioportal.bioontology.org/ontologies/1109)

## Accessing fixtures data in test(.t) files

- Get a [Bio::Chado::Schema](http://search.cpan.org/perldoc?Bio::Chado::Schema) aka [DBIx::Class](http://search.cpan.org/perldoc?DBIx::Class) object

my $schema = Module::Build->current->schema;

isa_ok($schema, 'Bio::Chado::Schema');

- Access them using [DBIx::Class](http://search.cpan.org/perldoc?DBIx::Class) API

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

## Loading custom fixtures

    - Create your own subclass and implement either or both of two methods
    __before_all_fixtures__ and __after_all_fixtures__
    - before_all_fixtures

    This code will run before any fixture is loaded

    - after_all_fixtures

    This code will run after organism data, relationship and sequence ontologies are loaded

    package MyBuilder;
    use base qw/Module::Build::Chado/;

    sub before_all_fixtures {
       my ($self) = @_;
    }

    sub before_all_fixtures {
       my ($self) = @_;
    }

- All the attributes and methods of __Module::Build__ and __Module::Build::Chado__ [API](http://search.cpan.org/perldoc?API)
become available through _$self_.

# ATTRIBUTES

## schema

A [Bio::Chado::Schema](http://search.cpan.org/perldoc?Bio::Chado::Schema) object.

## dsn

Database connect string,  defaults to a temporary SQLite database.

## user

Database user,  not needed for SQLite backend.

## password

Database password,  not needed for SQLite backend.

## superuser

Database super user, in case the regular use do not have enough permissions for
manipulating the database schema. It defaults to the user attribute.

## superpassword

Similar concept as superuser

## ddl

DDL file for particular backend,  by default comes for SQLite,  Postgresql and Oracle.

## organism_fixuture

Fixture for loading organisms,  by default the distribution comes with a organism.yaml
file.

## rel_fixuture

Relation ontology file in obo_xml format. The distribution includes a relationship.obo_xml
file.

## so_fixuture

Sequence ontology file in obo_xml format. By default,  it includes sofa.obo_xml file.

# METHODS

## connect_hash

Returns a hash with the following connection specific keys ...

- dsn
- user
- password
- dbi_attributes

## connect_info

Returns an 4 elements array with connection arguments identical to [DBI](http://search.cpan.org/perldoc?DBI)'s __connect__
method.

## Actions

### setup

### ACTION_setup

Sets up the basic parameters for the build object and loads the specific backend class. It
is called by every other action. Override of calling it separately absolutely not
recommended.

### create

### ACTION_create

Creates a database. However,  at this point it is not implemented for Postgresql and
Oracle backends. For that,  you need to use database specific client tools. For SQLite
backend the database is created when the schema is loaded.

### deploy

### ACTION_deploy

Deploy a chado database to the specified backend. Create action is implied.

### deploy_schema

### ACTION_deploy_schema

Deploy a chado database to the specified backend. Unlike the __deploy__ action,  create
action is not implied here. So,  except SQLite backend,  this action expects a database to
be created already.

### load_organism

### ACTION_load_organism

Loads the organism fixture to the deployed chado schema. __deploy_schema__ action is
implied.

### load_rel

### ACTION_load_rel

Load the relationship ontology. __deploy_schema__ action is implied.

### load_so

### ACTION_load_so

Load the sequence ontology. __load_rel__ action is implied.

### load_fixture

### ACTION_load_fixture

Load all fixtures in the given order.

- organism
- relationship ontology
- sequence ontology

__deploy_schema__ is implied.

### unload_rel

### ACTION_unload_rel

Deletes the relationship ontology.

### unload_so

### ACTION_unload_so

Deletes the sequence ontology.

### unload_organism

### ACTION_unload_organism

Deletes the organisms.

### unload_fixture

### ACTION_unload_fixture

Delete all fixtures including organism,  relationship and sequence ontologies.

### prune_fixture

### ACTION_prune_fixture

Delete all fixtures. However,  unlike running all the dependent unload_actions similar to
__unload_fixture__ it empties all the database tables. It runs a little bit faster than
__unload_fixture__.

### test

### ACTION_test

Overrides the default __Action_test__ of [Module::Build](http://search.cpan.org/perldoc?Module::Build). This action drop any existing
schema,  loads the fixture along with the schema,  runs all the tests and then drops the
schema.

### drop

### ACTION_drop

Drops the database. However,  except SQLite it is not implemented for Oracle and
Postgresql.

### drop_schema

### ACTION_drop_schema

Drops the database schema.

# API

# AUTHOR

Siddhartha Basu <biosidd@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Siddhartha Basu.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.