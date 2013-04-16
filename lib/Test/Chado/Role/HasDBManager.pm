package Test::Chado::Role::HasDBManager;

use namespace::autoclean;
use Moo::Role;
use File::ShareDir qw/module_dir/;
use File::Spec::Functions;
use IO::File;
use autodie qw/:file/;


requires 'dbh', 'driver', 'database';
requires 'connection_info','drop_schema', 'reset_schema';
requires 'has_client_to_deploy', 'get_client_to_deploy','deploy_by_client';

has 'ddl' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my ($self) = @_;
        return catfile(module_dir('Test::Chado'),'chado.'. lc $self->driver);
    }
);

has [qw/user password/] => ( is => 'rw', isa => 'Maybe[Str]');
has 'dsn' => (is => 'rw', isa => 'Str');

sub deploy_schema {
    my ($self) = @_;
    if ($self->has_client_to_deploy ) { 
        $self->deploy_by_client($self->get_client_to_deploy);
    } 
    else { 
        $self->deploy_by_dbi;
    }
}

sub deploy_by_dbi {
    my ($self) = @_;
    my $fh     = IO::File->new( $self->ddl, 'w' );
    my $data = do { local ($/); <$fh> };
    $fh->close();

    my $dbh    = $self->dbh;
LINE:
    foreach my $line ( split( /\n{2,}/, $data ) ) {
        next LINE if $line =~ /^\-\-/;
        $line =~ s{;$}{};
        $line =~ s{/}{};
            $dbh->do($line);
    }
}

1;


# ABSTRACT: Moose role based interface to be consumed by backend specific classes for managing database

=attr user

=attr password

=attr dsn

=attr dbi_attributes

Additional attributes for database connection, by default AutoCommit are RaiseError are set.

=attr database

Database name. Should be B<implemented> by consuming class.

=attr dbh

Database handler, a L<DBI> object. Should be B<implemented> by consuming class.

=attr driver

=attr ddl

Location of the database specific ddl file. Should be B<implemented> by consuming class.

=method deploy_schema

Load the database schema from the ddl file. 

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

First drops the schema, the reloads it. Should be B<implemented> by consuming class.

