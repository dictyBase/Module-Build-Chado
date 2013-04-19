package Test::Chado::DBManager::SqLite;

use namespace::autoclean;
use Moo;
use MooX::late;
use DBI;
use File::Temp qw/:POSIX/;
use IPC::Cmd qw/can_run run/;

with 'Test::Chado::Role::DBManager';

has '+dsn' => (
	lazy => 1, 
	default => sub {
		my $file = tmpnam();
		return "dbi:SQLite:dbname=$file";
	}
);

sub _build_dbh {
    my ($self) = @_;
    return DBI->connect($self->dsn, '', '', $self->dbi_attributes );
}

sub _build_database {
    my ($self) = @_;
    if ( $self->driver_dsn =~ /(dbname|(.+)?)=(\S+)/ ) {
        return $3;
    }
}

sub create_database {
	return 1;
}

sub drop_database {
	my ($self) = @_;
	return $self->dbh->disconnect;
}

sub drop_schema {
    my ($self) = @_;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare(
        qq{SELECT name FROM sqlite_master where type = 'table' });
    $sth->execute();
    while ( my ($table) = $sth->fetchrow_array() ) {
        $dbh->do(qq{ DROP TABLE $table });
    }
}

sub get_client_to_deploy {
	my ($self) = @_;
	my $cmd;
	if ($cmd = can_run 'sqlite3') {
		return $cmd;
	}
	elsif ($cmd = can_run 'sqlite') {
		return $cmd;
	}
	else {
		return $cmd;
	}
}

sub deploy_by_client {
	my ($self, $client) = @_;
    my $cmd
        = [ $client, '-noheader', $self->database, '<', $self->ddl ];
    my ( $success, $error_code, $full_buf,, $stdout_buf, $stderr_buf )
        = run( command => $cmd, verbose => 1 );
    return $success if $success;
    die "unable to run command : ", $error_code, " ", $stderr_buf;
}

1;
