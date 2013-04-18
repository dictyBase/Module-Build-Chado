package Test::Chado::Role::HasDBManager;

use namespace::autoclean;
use Moo::Role;
use MooX::late;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;
use IO::File;
use autodie qw/:file/;
use DBI;

requires '_build_dbh', '_build_database';
requires 'drop_schema', 'create_database',  'drop_database';
requires 'has_client_to_deploy', 'get_client_to_deploy', 'deploy_by_client';

has 'dbh' => (
    is      => 'rw',
    isa     => 'DBI::db',
    lazy    => 1,
    builder => '_build_dbh'
);

has 'dbi_attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return { AutoCommit => 1, RaiseError => 1 };
    }
);

has 'database' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_database'
);

has 'driver' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'ddl' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return catfile( module_dir('Test::Chado'),
            'chado.' . lc $self->driver );
    }
);

has [qw/user password/] => ( is => 'rw', isa => 'Str' );
has 'driver_dsn' => (is => 'rw',  isa => 'Str');
has 'dsn' => (
    is      => 'rw',
    isa     => 'Str',
    trigger => sub {
        my ( $self, $value ) = @_;
        my ( $scheme, $driver, $attr_str, $attr_hash, $driver_dsn )
            = DBI->parse_dsn($value);
        $self->driver($driver);
        $self->driver_dsn($driver_dsn);
    }
);

sub deploy_schema {
    my ($self) = @_;
    if ( $self->has_client_to_deploy ) {
        $self->deploy_by_client( $self->get_client_to_deploy );
    }
    else {
        $self->deploy_by_dbi;
    }
}

sub deploy_by_dbi {
    my ($self) = @_;
    my $fh = IO::File->new( $self->ddl, 'w' );
    my $data = do { local ($/); <$fh> };
    $fh->close();

    my $dbh = $self->dbh;
LINE:
    foreach my $line ( split( /\n{2,}/, $data ) ) {
        next LINE if $line =~ /^\-\-/;
        $line =~ s{;$}{};
        $line =~ s{/}{};
        $dbh->do($line);
    }
}


sub reset_schema {
	my ($self) = @_;
	$self->drop_schema;
	$self->deploy_schema;
}

1;

# ABSTRACT: Moose role based interface to be consumed by backend specific classes for managing database

=attr user

=attr password

=attr dsn

=attr database

Database name. The method B<_build_database> should be B<implemented> by consuming class.

=attr dbh

Database handler, a L<DBI> object. The method <_build_dbh> should be B<implemented> by consuming class.

=attr driver

Name of the database backend. It is being set from dsn value.

=attr driver_dsn

=attr ddl

Location of the database specific ddl file. Should be B<implemented> by consuming class.

=attr dbi_attributes

Extra parameters for database connection, by default RaiseError and AutoCommit are set.

=method deploy_schema

Load the database schema from the ddl file. Should be B<implemented> by consuming class.

=method has_client_to_deploy

Check to see if the backend can provide command line client for deploying schema. Should be B<implemented> by consuming class.

=method get_client_to_deploy

Full path for the command line client. Should be B<implemented> by consuming class.

=method deploy_by_client

Use backend specific command line tool to deploy the schema. Should be B<implemented> by consuming class.

=method deploy_by_dbi

Deploy schema using DBI

=method drop_schema

Drop the loaded schema. Should be B<implemented> by consuming class.

=method reset_schema

First drops the schema, the reloads it. 

=method create_database

Create database. Should be B<implemented> by consuming class.

=method drop_database

Drop database. Should be B<implemented> by consuming class.
