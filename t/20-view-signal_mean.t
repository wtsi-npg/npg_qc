#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-16
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 6;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::signal_mean;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::view::signal_mean');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

my $util  = t::util->new({});
{
  my $model = npg_qc::model::signal_mean->new({util => $util});
  my $view  = npg_qc::view::signal_mean->new({
    util   => $util,
    model  => $model,
    action => 'read',
    aspect => 'read_png',
  });

  isa_ok($view, 'npg_qc::view::signal_mean', '$view');
  is($view->decor(), 0, 'aspect read_png decor ok');
  is($view->content_type(), 'image/png', 'aspect read_png content_type ok');
}

{
  my $model = npg_qc::model::signal_mean->new({util => $util});
  my $view  = npg_qc::view::signal_mean->new({
    util   => $util,
    model  => $model,
    action => 'list',
    aspect => q{},
  });

  is($view->decor(), 1, 'action list decor ok');
  is($view->content_type(), 'text/html', 'action list content_type ok');
}

1;
__END__
