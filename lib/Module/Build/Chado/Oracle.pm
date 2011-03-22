package Module::Build::Chado::Oracle;

# Other modules:
use namespace::autoclean;
use Moose;
use Try::Tiny;
use DBI;
use DBD::Oracle qw/:ora_session_modes/;
use Carp;
use Path::Class::File;

# Module implementation
#

has 'dbi_attributes' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { { AutoCommit => 0, LongReadLen => 2**25 } },
    handles => { add_dbi_attribute => 'set' }
);

sub create_db {
    my ($self) = @_;
    ## -- still not sure how to connect as the user before creating them ... so ...
    warn "not implemented for oracle: you need to create the database with appropiate permissions\n";
    return 1;
}

sub drop_db {
    my ($self) = @_;
    ## -- still not sure how to drop a schema by connecting as same user
    ## -- so this action actually drop the database structure
    warn "not implemented for oracle: you need to drop the schema manually\n";
    return 1;
}

sub prune_fixture {
    my ($self) = @_;
    my $dbh = $self->super_dbh;

    my $tsth = $dbh->prepare(qq{ select table_name FROM user_tables });
    $tsth->execute() or croak $tsth->errstr();
    while ( my ($table) = $tsth->fetchrow_array() ) {
        try { $dbh->do(qq{ TRUNCATE TABLE $table }) }
        catch {
            $dbh->rollback();
            croak "$_\n";
        };
    }
    $dbh->commit;
}

sub drop_schema {
    my ($self) = @_;
    my $dbh = $self->super_dbh;
    my $sidx
        = $dbh->prepare(
        qq{select index_name, table_name FROM user_indexes where generated = 'N'}
        );
    my $tgsth = $dbh->prepare(
        qq { select trigger_name,table_name FROM user_triggers });
    my $vsth = $dbh->prepare(qq{ select view_name FROM user_views });
    my $isth = $dbh->prepare(qq{ select sequence_name FROM user_sequences });
    my $tsth = $dbh->prepare(qq{ select table_name FROM user_tables });
    my $psth = $dbh->prepare(
        qq{select distinct(prv_preference) from ctx_user_preference_values});

    $tsth->execute() or croak $tsth->errstr();
TABLE:
    while ( my ($table) = $tsth->fetchrow_array() ) {
        next TABLE if $table =~ /CTX/;
        try { $dbh->do(qq{ drop table $table cascade constraints purge }) }
        catch {
            $dbh->rollback();
            confess "$_\n";
        };
    }

    $isth->execute() or croak $isth->errstr();
LINE:
    while ( my ($seq) = $isth->fetchrow_array() ) {
        if ( $seq =~ /^SQ/ ) {
            try {
                $dbh->do(qq{ drop sequence $seq });
            }
            catch {
                $dbh->rollback();
                confess "$_\n";
            };
        }
    }

    $sidx->execute() or croak $dbh->errstr();
INDEX:
    while ( my ( $name, $table ) = $sidx->fetchrow_array() ) {
        try {
            $dbh->do(qq{ alter table $table drop constraint $name cascade });
        }
        catch {
            $dbh->rollback();
            confess "$_\n";
        };
    }

    $vsth->execute() or croak $dbh->errstr();
VIEW:
    while ( my ($view) = $vsth->fetchrow_array() ) {
        try { $dbh->do(qq{ drop view $view cascade constraints }) }
        catch {
            $dbh->rollback();
            confess "$_\n";
        };
    }

    $tgsth->execute() or croak $dbh->errstr();
TRIGGER:
    while ( my ( $trigger, $table ) = $tgsth->fetchrow_array() ) {
        next TRIGGER if $table =~ /\$0$/;
        try { $dbh->do(qq { drop trigger $trigger }) }
        catch {
            $dbh->rollback();
            confess "$_\n";
        };
    }

    $psth->execute or croak $psth->errstr();
PREF:
    while ( my ($preference) = $psth->fetchrow_array() ) {
        $preference = "'" . $preference . "'";
        try {
            $dbh->do(
                qq{
				BEGIN
			 		ctx_ddl.drop_preference($preference);
				END;
			  }
            );
        }
        catch {
            $dbh->rollback;
            confess "$_\n";
        }
    }

    $dbh->commit;
}

has 'dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->add_dbi_attribute( 'AutoCommit',  0 );
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        return $dbh;
    }
);

has 'super_dbh' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->add_dbi_attribute( 'AutoCommit',  0 );
        DBI->connect( $self->super_connection_info ) or confess $DBI::errstr;
    }
);

has 'dbh_withcommit' => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->add_dbi_attribute( 'AutoCommit',  1 );
        $self->add_dbi_attribute( 'RaiseError',  1 );
        my $dbh = DBI->connect( $self->connection_info )
            or confess $DBI::errstr;
        return $dbh;
    }
);

sub connection_info {
    my ($self) = @_;
    return ( $self->dsn, $self->user, $self->password, $self->dbi_attributes );
}

sub super_connection_info {
    my ($self) = @_;
    return (
        $self->dsn,           $self->superuser,
        $self->superpassword, $self->dbi_attributes
    );
}

sub deploy_schema {
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

sub deploy_post_schema {
    my ($self) = @_;
    my $dbh    = $self->dbh;
    my $fh     = Path::Class::File->new( $self->post_ddl )->openr;
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
    return;
}

with 'Module::Build::Chado::Role::HasDB';

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

# ABSTRACT: Oracle specific class for Module::Build::Chado
