package Module::Build::Chado::Pg;

# Other modules:
use namespace::autoclean;
use Moose;
use Try::Tiny;
use Path::Class;
use DBI;
use Carp;

# Module implementation
#

has 'dbi_attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { { AutoCommit => 0 } },
    handles => { add_dbi_attribute => 'set' }
);

sub database {
    my ($self) = @_;
    if ( $self->driver_dsn =~ /d(atabase|b|bname)=(\w+)\;/ ) {
        return $2;
    }
}

sub create_db {
    my ($self) = @_;
    carp "not implemented for postgresql: use **createdb** instead\n";
    return 1;
}

sub drop_db {
    my ($self) = @_;
    carp "not implemented for postgresql: use **dropdb** instead\n";
    return 1;
}

has 'dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->add_dbi_attribute( 'AutoCommit', 0 );
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        $dbh->do(qq{SET client_min_messages=WARNING});
        return $dbh;
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
        $dbh->do(qq{SET client_min_messages=WARNING});
        return $dbh;
    }
);

has 'super_dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->add_dbi_attribute( 'AutoCommit', 0 );
        my $dbh = DBI->connect( $self->super_connection_info )
            or confess $DBI::errstr;
        $dbh->do(qq{SET client_min_messages=WARNING});
        return $dbh;
    }
);

sub connection_info {
    my ($self) = @_;
    return ( $self->dsn, $self->user, $self->password,
        $self->dbi_attributes );
}

sub super_connection_info {
    my ($self) = @_;
    return ( $self->dsn, $self->superuser, $self->superpassword,
        $self->dbi_attributes );
}

sub deploy_schema {
    my ($self) = @_;
    my $schema = $self->schema;
    my $allowed_sources = [ grep { !/Composite/i } $schema->sources ];
    $schema->deploy( { parser_args => { sources => $allowed_sources } } );
}

sub prune_fixture {
    my ($self) = @_;
    my $dbh    = $self->super_dbh;
    my $tsth   = $dbh->prepare(
        "SELECT relname FROM pg_class WHERE relnamespace IN
          (SELECT oid FROM pg_namespace WHERE nspname='public')
          AND relkind='r';"
    );
    $tsth->execute() or croak $tsth->errstr();
    while ( my ($table) = $tsth->fetchrow_array() ) {
        try {
            $dbh->do(qq{ TRUNCATE TABLE $table CASCADE });
            $dbh->commit;
        }
        catch {
            $dbh->rollback();
            croak "$_\n";
        };
    }
}

sub drop_schema {
    my ($self) = @_;
    my $dbh    = $self->dbh;
	my $tsth   = $dbh->prepare(
        "SELECT relname FROM pg_class WHERE relnamespace IN
          (SELECT oid FROM pg_namespace WHERE nspname='public')
          AND relkind='r';"
    );

    my $vsth   = $dbh->prepare(
        "SELECT viewname FROM pg_views WHERE schemaname NOT IN ('pg_catalog',
			 'information_schema') AND viewname !~ '^pg_'"
    );

    my $seqth = $dbh->prepare(
        "SELECT relname FROM pg_class WHERE relkind = 'S' AND relnamespace IN ( SELECT oid FROM
	 pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname != 'information_schema')"
    );

    $tsth->execute or croak $tsth->errstr;
    while ( my ($table) = $tsth->fetchrow_array ) {
        try {
            $dbh->do(qq{ drop table $table cascade });
            $dbh->commit;
        }
        catch {
            $dbh->rollback();
            croak "$_";
        };
    }

    my $seqs = join( ",",
        map { $_->{relname} }
            @{ $dbh->selectall_arrayref( $seqth, { Slice => {} } ) } );

    if ($seqs) {
        try { $dbh->do(qq{ drop sequence if exists $seqs }); $dbh->commit; }
        catch {
            $dbh->rollback();
            croak "$_\n";
        };
    }

    my $views = join( ",",
        map { $_->{viewname} }
            @{ $dbh->selectall_arrayref( $vsth, { Slice => {} } ) } );

    if ($views) {
        try { $dbh->do(qq{ drop view if exists $views }); $dbh->commit; };
        catch {
            $dbh->rollback();
            croak "$_\n";
        };
    }
}

with 'Module::Build::Chado::Role::HasDB';

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module


# ABSTRACT: Postgresql specific class for Module::Build::Chado
