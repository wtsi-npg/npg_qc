package t::util;

use Carp;
use English qw{-no_match_vars};
use Moose;
use Class::Load qw/load_class/;;
use Readonly;

with 'npg_testing::db';

Readonly::Scalar our $CONFIG_PATH       => q[t/data/test_app.conf];
Readonly::Scalar our $CONFIG_PATH_NO_DB => q[t/data/test_app_no_db.conf];
Readonly::Scalar our $STAGING_PATH      => q[t/data];
Readonly::Scalar our $MLWHOUSE_DB_PATH  => q[t/data/mlwarehouse.db];
Readonly::Scalar our $NPGQC_DB_PATH     => q[t/data/npgqc.db];
Readonly::Scalar our $NPG_DB_PATH       => q[t/data/npg.db];

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

has 'staging_path' => ( isa      => 'Str',
                        is       => 'ro',
                        required => 0,
                        default  => sub {$STAGING_PATH},
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
    my $npg = $schemas->{'npg'};
    $npg->resultset('Run')->find({id_run => 4025, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3965, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3323, })->set_tag(1, 'staging');
    $npg->resultset('Run')->find({id_run => 3500, })->set_tag(1, 'staging');
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

sub authorise {
  my ($p, $c, @roles) = @_;
  my $user = $c->req->params->{'user'} || q[];
  my $password = $c->req->params->{'password'} || q[];
  $c->logout;
  if (!$c->authenticate({username => $user, password => $password})) {
    die q[Login failed];
  }
  if (!$c->user->username) {
    die q[User is not logged in];
  }
  if (@roles && !$c->check_user_roles(@roles) ) {
    die sprintf q[User %s is not a member of %s],
      $c->user->username, join q[,], @roles;
  }
  return;
}

sub DEMOLISH {
  my $self = shift;
  if (-e $self->mlwhouse_db_path) {unlink $self->mlwhouse_db_path;}
  if (-e $self->npgqc_db_path)    {unlink $self->npgqc_db_path;}
  if (-e $self->npg_db_path)      {unlink $self->npg_db_path;}
}

no Moose;
1;
