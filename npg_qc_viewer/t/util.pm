package t::util;

use Carp;
use English qw{-no_match_vars};
use Moose;
use Readonly;

with 'npg_testing::db';

Readonly::Scalar our $CONFIG_PATH        => q[t/data/test_app.conf];
Readonly::Scalar our $CONFIG_PATH_NO_DB  => q[t/data/test_app_no_db.conf];
Readonly::Scalar our $STAGING_PATH   => q[t/data];
Readonly::Scalar our $WHOUSE_DB_PATH => q[t/data/warehouse.db];
Readonly::Scalar our $NPGQC_DB_PATH  => q[t/data/npgqc.db];
Readonly::Scalar our $NPG_DB_PATH    => q[t/data/npg.db];

has 'config_path' => ( isa      => 'Str',
                       is       => 'ro',
                       required => 0,
                       lazy_build => 1,
                     );
sub _build_config_path {
    my $self = shift;
    if (!$self->db_connect) {
        return $CONFIG_PATH_NO_DB;
    }
    return $CONFIG_PATH;
}

has 'db_connect'  => ( isa      => 'Bool',
                       is       => 'ro',
                       required => 0,
                       default  => 1,
		     );

has 'staging_path' => ( isa      => 'Str',
                        is       => 'ro',
                        required => 0,
                        default  => sub {$STAGING_PATH},
                      );

has 'whouse_db_path' => ( isa      => 'Str',
                          is       => 'ro',
                          required => 0,
                          default  => sub {$WHOUSE_DB_PATH},
                        );

has 'npgqc_db_path' => ( isa      => 'Str',
                         is       => 'ro',
                         required => 0,
                         default  => sub {$NPGQC_DB_PATH},
                       );

has 'npg_db_path'   => ( isa      => 'Str',
                         is       => 'ro',
                         required => 0,
                         default  => sub {$NPG_DB_PATH},
                       );

sub test_env_setup {

    my $self = shift;

    my $schemas = {};

    my $db = $self->whouse_db_path;
    if (-e $db) {unlink $db;}
    my $schema_package = q[npg_warehouse::Schema];
    my $fixtures_path = q[t/data/fixtures/warehouse];
    $schemas->{wh} = $self->create_test_db($schema_package, $fixtures_path, $db);

    $db = $self->npgqc_db_path;
    if (-e $db) {unlink $db;}
    $schema_package = q[npg_qc::Schema];
    $fixtures_path = q[t/data/fixtures/npgqc];
    $schemas->{qc} = $self->create_test_db($schema_package, $fixtures_path, $db);


    $db = $self->npg_db_path;
    if (-e $db) {unlink $db;}
    $schema_package = q[npg_tracking::Schema];
    $fixtures_path = q[t/data/fixtures/npg];
    $schemas->{npg} = $self->create_test_db($schema_package, $fixtures_path, $db);

    my $npg = $schemas->{npg};
    $npg->resultset('Run')->find({id_run => 4025, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3965, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3323, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3500, })->set_tag(1, 'staging');

    return $schemas;
}


sub DEMOLISH {
    my $self = shift;
    if (-e $self->whouse_db_path) {unlink $self->whouse_db_path;} 
    if (-e $self->npgqc_db_path) {unlink $self->npgqc_db_path;}
    if (-e $self->npg_db_path) {unlink $self->npg_db_path;} 
}

no Moose;
1;
