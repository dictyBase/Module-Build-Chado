package TestBackend;
use Moo;
use DBI;

sub _build_dbh {
}

sub _build_database { }

sub drop_schema {
}

sub reset_schema {
}

sub get_client_to_deploy {
}

sub deploy_by_client {
}

sub create_database { }

sub drop_database { }

with 'Test::Chado::Role::HasDBManager';

1;

package main;
use Test::More qw/no_plan/;

my $backend = new_ok('TestBackend');

my @required_by_role = qw(_build_database _build_dbh
    drop_schema get_client_to_deploy deploy_by_client
    create_database drop_database);
my @consumed_from_role
    = qw(reset_schema driver_dsn dbh dbi_attributes database driver ddl user password dsn deploy_schema deploy_by_dbi);
can_ok( $backend, @required_by_role );
can_ok( $backend, @consumed_from_role );

