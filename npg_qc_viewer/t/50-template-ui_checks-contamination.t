use strict;
use warnings;
use Template;
use Template::Plugin::Number::Format;
use Test::More tests => 2;


{
  my $tt = Template->new();
  my $template = q[root/src/ui_checks/contamination.tt2];
  my $output = q[];
  ok($tt->process($template, {}, \$output), 'no-input template processed');
  ok(!$tt->error(), 'no errors for no-input template');
}

1;
