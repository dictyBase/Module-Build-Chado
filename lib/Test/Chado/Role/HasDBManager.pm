package Test::Chado::Role::HasDBManager;

use namespace::autoclean;
use Moo::Role;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;


requires 'user', 'password', 'dsn', 'dbh', 'driver';
requires 'deploy_schema','drop_schema';

has 'ddl' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my ($self) = @_;
        return catfile(module_dir('Test::Chado'),'chado.'. lc $self->driver);
    }
);

1;


# ABSTRACT: Moose role based interface to be consumed by backend specific classes for managing database

=attr user

=attr password

=attr dsn

=attr dbh

Database handler, a L<DBI> object.

=attr driver

=attr ddl

Location of the database specific ddl file.

=method deploy_schema

Load the database schema from the ddl file.

=method drop_schema

Drop the loaded schema

=method reset_schema

First drops the schema, the reloads it.

