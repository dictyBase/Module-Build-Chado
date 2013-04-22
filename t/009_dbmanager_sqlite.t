package main;
use Test::More qw/no_plan/;
use IPC::Cmd qw/can_run/;
use Test::Exception;

use_ok('Test::Chado::DBManager::SqLite');
my $sqlite = new_ok('Test::Chado::DBManager::SqLite');

like( $sqlite->dsn, qr/dbi:SQLite:dbname=\S+/, 'should match a Sqlite dsn' );
like( $sqlite->database, qr/^\S+$/, 'should match the database name' );
isa_ok( $sqlite->dbh, 'DBI::db' );
SKIP: {
    my $client = can_run('sqlite3');
    skip 'sqlite client is not installed', if !$client;

    lives_ok { $sqlite->get_client_to_deploy} 'should have a command line client';
    lives_ok { $sqlite->deploy_by_client } 'should deploy with command line client';

    my @row = $sqlite->dbh->selectrow_array(
        "SELECT name FROM sqlite_master where
	type = ? and table_name = ?", {}, qw/table feature/
    );

    ok( @row, "should have feature table present in the database" );

    lives_ok { $sqlite->drop_schema } "should drop the schema";

    my @row2 = $sqlite->dbh->selectrow_array(
        "SELECT name FROM sqlite_master where
	type = ? and table_name = ?", {}, qw/table feature/
    );

    isnt( @row2, 1, "should not have feature table in the database" );
}
