package Module::Build::Chado::Sqlite;

# Other modules:
use namespace::autoclean;
use Moose;
use Carp;
use File::Basename;
use File::Path;
use Try::Tiny;
use IPC::Cmd qw/can_run run/;
use Path::Class;

# Module implementation
#

has 'dbi_attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { { AutoCommit => 0 } },
    handles => { add_dbi_attribute => 'set' }
);

has 'dbh' => (
    is        => 'ro',
    isa       => 'DBI::db',
    predicate => 'has_db',
    lazy      => 1,
    default   => sub {
        my ($self) = @_;
        $self->add_dbi_attribute( 'AutoCommit', 0 );
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        $dbh->do("PRAGMA foreign_keys = ON");
        $dbh;
    }
);

has 'dbh_withcommit' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->add_dbi_attribute( 'AutoCommit', 1 );
        $self->add_dbi_attribute( 'RaiseError', 1 );
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        $dbh->do("PRAGMA foreign_keys = ON");
        return $dbh;
    }
);

sub drop_db {
    my ($self) = @_;
    $self->dbh->disconnect;
    $self->dbh_withcommit->disconnect;
    my $dbname = $self->database;
    unlink $dbname or die "unable to remove $dbname sqlite database\n";
}

sub database {
    my ($self) = @_;
    if ( $self->module_builder->driver_dsn =~ /(dbname|(.+)?)=(\S+)/ ) {
        return $3;
    }
}

sub create_db {
    return 1;
}

sub connection_info {
    my ($self) = @_;
    return ( $self->dsn, '', '', $self->dbi_attributes );
}

sub deploy_schema {
    my $self = shift;
    if ( my $cmd = can_run 'sqlite3' ) {
        $self->deploy_by_client($cmd);
    }
    else {
        $self->deploy_by_dbi;
    }
}

sub deploy_post_schema {
    return;
}

sub deploy_by_client {
    my ($self, $cmd_path) = @_;
    my $cmd
        = [ $cmd_path, '-noheader', $self->database, '<', $self->ddl ];
    my ( $success, $error_code, $full_buf,, $stdout_buf, $stderr_buf )
        = run( command => $cmd, verbose => 1 );
    return $success if $success;
    carp "unable to run command : ", $error_code, " ", $stderr_buf;
}

sub deploy_by_dbi {
    my ($self) = @_;
    my $dbh    = $self->dbh;
    my $fh     = Path::Class::File->new( $self->ddl )->openr;
    my $data = do { local ($/); <$fh> };
    $fh->close();
LINE:
    foreach my $line ( split( /\n{2,}/, $data ) ) {
        next LINE if $line =~ /^\-\-/;
        $line =~ s{;$}{};
        $line =~ s{/}{};
        try {
            $dbh->do($line);
            $dbh->commit;
        }
        catch {
            $dbh->rollback;
            confess $_, "\n";
        };
    }
}

sub run_fixture_hooks {
    my ($self) = @_;
    $self->dbh->do("PRAGMA foreign_keys = ON");
}

sub prune_fixture {
    my ($self) = @_;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare(
        qq{SELECT name FROM sqlite_master where type = 'table' });
    $sth->execute() or croak $sth->errstr;
    while ( my ($table) = $sth->fetchrow_array() ) {
        try {
            $dbh->do(qq{ DELETE FROM $table });
        }
        catch {
            $dbh->rollback;
            croak "Unable to clean table $table: $_\n";
        };
    }
    $dbh->commit;
}

sub drop_schema {
    my ($self) = @_;
    my $dbh = $self->dbh;

    my $sth = $dbh->prepare(
        qq{SELECT name FROM sqlite_master where type = 'table' });
    $sth->execute() or croak $sth->errstr;
    while ( my ($table) = $sth->fetchrow_array() ) {
        try {
            $dbh->do(qq{ DROP TABLE $table });
        }
        catch {
            $dbh->rollback;
            croak "Unable to clean table $table: $_\n";
        };
    }
    $dbh->commit;

}

with 'Module::Build::Chado::Role::HasDB';

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

# ABSTRACT: SQLite specific class for Module::Build::Chado
