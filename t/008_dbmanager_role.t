package TestBackend;
use Moo;
use DBI;
with 'Test::Chado::DBManager::Sqlite';

has 'dbh' => (
    is      => 'rw',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return DBI->connect( $self->dsn, '', '', $self->dbi_attributes );
    }
);

has '+dsn' => ( default => sub { return 'dbi:SQLite:dbname=:memory:' },  lazy => 1 );

has 'driver' => ( is => 'rw', isa => 'Str', lazy => 1, default => 'SQLite' );

sub database { return 1 }

sub drop_schema {
}

sub reset_schema {
	return 1;
}

sub has_client_to_deploy {
	return 0;
}

sub get_client_to_deploy {
	return 0;
}

sub deploy_by_client {
	return 0;
}
