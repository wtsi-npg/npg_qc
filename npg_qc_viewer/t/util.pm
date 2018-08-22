package t::util;

use Moose;
use Class::Load qw/load_class/;
use Readonly;
use Archive::Extract;
use File::Temp qw/ tempdir /;
use Cwd;

use npg_qc::autoqc::db_loader;
with 'npg_testing::db';

Readonly::Scalar our $CONFIG_PATH       => q[t/data/test_app.conf];
Readonly::Scalar our $CONFIG_PATH_NO_DB => q[t/data/test_app_no_db.conf];
Readonly::Scalar our $MLWHOUSE_DB_PATH  => q[t/data/mlwarehouse.db];
Readonly::Scalar our $NPGQC_DB_PATH     => q[t/data/npgqc.db];
Readonly::Scalar our $NPG_DB_PATH       => q[t/data/npg.db];

has 'config_path' => ( isa        => 'Str',
                       is         => 'ro',
                       required   => 0,
                       lazy_build => 1,
                     );
sub _build_config_path {
  my $self = shift;
  if (!$self->db_connect) {
    return $CONFIG_PATH_NO_DB;
  }
  return $CONFIG_PATH;
}

has 'fixtures'  => ( isa      => 'Bool',
                     is       => 'ro',
                     required => 0,
                     default  => 1,
		               );

has 'db_connect'  => ( isa      => 'Bool',
                       is       => 'ro',
                       required => 0,
                       default  => 1,
		                 );

has 'mlwhouse_db_path' => (
                            isa      => 'Str',
                            is       => 'ro',
                            required => 0,
                            default  => sub {$MLWHOUSE_DB_PATH},
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

  my $db = $self->mlwhouse_db_path;
  if (-e $db) {unlink $db;}
  my $schema_package  = q[WTSI::DNAP::Warehouse::Schema];
  my $fixtures_path   = $self->fixtures ? q[t/data/fixtures/mlwarehouse] : q[];
  $schemas->{'mlwh'}    = $self->create_test_db($schema_package, $fixtures_path, $db);


  $db = $self->npgqc_db_path;
  if (-e $db) {unlink $db;}
  $schema_package = q[npg_qc::Schema];
  $fixtures_path  = $self->fixtures ? q[t/data/fixtures/npgqc] : q[];
  $schemas->{'qc'}  = $self->create_test_db($schema_package, $fixtures_path, $db);

  $db = $self->npg_db_path;
  if (-e $db) {unlink $db;}
  $schema_package = q[npg_tracking::Schema];
  $fixtures_path  = $self->fixtures ? q[t/data/fixtures/npg] : q[];
  $schemas->{'npg'} = $self->create_test_db($schema_package, $fixtures_path, $db);

  if ($self->fixtures) {
    my $rows = {};
    foreach my $id ((4025, 3965, 3500)) {
      my $row = $schemas->{'npg'}->resultset('Run')->find($id);
      if (!$row) {
        die "No row for run $id";
      }
      $rows->{$id} = $row;
      $row->set_tag(1, 'staging');
    }

    my $cwd = getcwd();
    $rows->{4025}->update(
      {folder_name => '091106_IL38_4025',
       folder_path_glob => $cwd . '/t/data/nfs/sf44/IL38/outgoing'});
    $rows->{3965}->update(
      {folder_name => '091025_IL36_3965',
       folder_path_glob => $cwd . '/t/data/nfs/sf44/IL36/analysis'});

    my $tempdir = tempdir( CLEANUP => 1);
    my $ae = Archive::Extract->new(
      archive => 't/data/fixtures/npgqc_json.tar.gz');
    $ae->extract(to => $tempdir) or die $ae->error;

    npg_qc::autoqc::db_loader->new(
      schema  => $schemas->{'qc'},
      path    => ["${tempdir}/npgqc_json"],
      verbose => 0
    )->load();
  }
 
  return $schemas;
}

sub modify_logged_user_method {
  my $class = 'npg_qc_viewer::Model::User';
  load_class($class);
  $class->meta->add_around_method_modifier('logged_user', \&logged_user4test_domain);
  return; 
}

sub logged_user4test_domain {
  my $orig = shift;
  my $self = shift;
  my $c    = shift;
  my $user = $c->req->params->{'user'} || q[];
  my $password = $c->req->params->{'password'} || q[];
  return $self->$orig($c,{username => $user, password => $password});
}

sub DEMOLISH {
  my $self = shift;
  if (-e $self->mlwhouse_db_path) {unlink $self->mlwhouse_db_path;}
  if (-e $self->npgqc_db_path)    {unlink $self->npgqc_db_path;}
  if (-e $self->npg_db_path)      {unlink $self->npg_db_path;}
}

no Moose;
1;
