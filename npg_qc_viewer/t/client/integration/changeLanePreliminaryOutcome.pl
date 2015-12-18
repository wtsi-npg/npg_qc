use strict;
use warnings;
use Selenium::Firefox;
use strict;

my $HTTP_SERVER = $ENV{'HTTP_SERVER'} || q[localhost];
my $HTTP_PORT   = $ENV{'HTTP_PORT'}   || q[8080];
my $PAUSE_FACTOR = $ENV{'PAUSE_FACTOR'} || 1;
my $AUTH_COOKIE = $ENV{'AUTH_COOKIE'} || 'TestAuthCookie';
my $url   = 'http://' . $HTTP_SERVER . ':' . $HTTP_PORT . '/checks/runs/18335';
my $title = 'NPG SeqQC v0: Results for run 18335 (current run status: qc in progress, taken by jmtc)';
my $driver = Selenium::Firefox->new( startup_timeout => 60 );

my $user_a = 'jmtc'; 
my $user_b = 'en3';

sub change_outcome {
  my ( $driver, $lane, $outcome ) = @_;
  $driver->find_element('//*[@id="mqc_lane' . $lane . '"]/label[' . $outcome . ']', 'xpath')->click();
}

sub change_user {
  my ($driver, $user) = @_;
  if ($user eq q'') {
    $driver->delete_cookie_named($AUTH_COOKIE);
  } else {
    $driver->add_cookie($AUTH_COOKIE, $user, '/', '');
  }
}

$driver->set_implicit_wait_timeout(10000 * $PAUSE_FACTOR);
$driver->get($url);
$driver->pause(3000 * $PAUSE_FACTOR);
$driver->execute_script(q[javascript:window.scrollBy(0,1500);]);
$driver->pause(2000 * $PAUSE_FACTOR);

change_user($driver, $user_a);
$driver->get($url);
$driver->pause(3000 * $PAUSE_FACTOR);
for (my $i = 0; $i < 8; $i+=2) {
  change_outcome($driver, $i + 1, 1); #Accepted preliminary
}
$driver->pause(3000 * $PAUSE_FACTOR);
$driver->execute_script(q[javascript:window.scrollBy(0,1500);]);
$driver->pause(2000 * $PAUSE_FACTOR);

change_user($driver, $user_b);
$driver->get($url);
$driver->pause(3000 * $PAUSE_FACTOR);

change_user($driver, $user_a);
$driver->get($url);
$driver->pause(3000 * $PAUSE_FACTOR);
for (my $i = 0; $i < 8; $i+=2) {
  change_outcome($driver, $i + 1, 2); #Undecided
}
$driver->pause(3000 * $PAUSE_FACTOR);

$driver->quit();
