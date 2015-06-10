use strict;
use warnings;
use Template;
use Test::More tests => 2;
use Test::Exception;

{
  my $tt = Template->new();
  my $template = q[root/src/ui_checks/gc_bias.tt2];
  my $output = q[];
  ok($tt->process($template, {}, \$output), 'no-input template processed');
  ok(!$tt->error(), 'no-input template processed without errors');
}

1;

