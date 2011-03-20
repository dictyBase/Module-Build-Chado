package Module::Build::Chado::Pg;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Try::Tiny;
use Path::Class;
use DBI;
use Carp;

# Module implementation
#
with 'Module::Build::Chado::Role::HasDB';

has 'dbi_attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { { AutoCommit => 0 } },
    handles => { add_dbi_attribute => 'set' }
);


sub database {
    my ($self) = @_;
    if ( $self->module_builder->driver_dsn =~ /d(atabase|b|bname)=(\w+)\;/ ) {
        return $2;
    }
}

sub create_db {
    my ($self) = @_;
    return 1;
    my $user     = $self->superuser;
    my $password = $self->superpass;
    my $dbname   = $self->database;
    try {
        $self->super_dbh->do("CREATE DATABASE $dbname");
    }
    catch {
        confess "cannot create database $dbname\n";
    };
}

sub drop_db {
    my ($self) = @_;
    $self->drop_schema;
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
    return ( $self->dsn, $self->user, $self->password, $self->dbi_attributes );
}

sub super_connection_info {
    my ($self) = @_;
    return ( $self->dsn, $self->superuser, $self->superpassword, $self->dbi_attributes );
}

sub deploy_schema {
    my ($self) = @_;
    my $schema = $self->schema;
    $schema->deploy;
}

sub prune_fixture {
    my ($self) = @_;
    my $dbh = $self->super_dbh;

    my $tsth = $dbh->prepare(qq{ select table_name FROM user_tables });
    $tsth->execute() or croak $tsth->errstr();
    while ( my ($table) = $tsth->fetchrow_array() ) {
        try { $dbh->do(qq{ TRUNCATE TABLE $table CASCADE }) }
        catch {
            $dbh->rollback();
            croak "$_\n";
        };
    }
    $dbh->commit;
}

sub drop_schema {
    my ($self) = @_;
    my $dbh    = $self->dbh_nocommit;
    my $tsth   = $dbh->prepare(
        "SELECT relname FROM pg_class WHERE relnamespace IN
          (SELECT oid FROM pg_namespace WHERE nspname='public')
          AND relkind='r';"
    );

    my $vsth = $dbh->prepare(
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

__PACKAGE__meta->make_immutable;

1;    # Magic true value required at end of module

