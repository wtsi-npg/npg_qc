use strict;
use warnings;
use Template;
use Template::Plugin::Number::Format;
use Test::More tests => 1;
use Test::Exception;


{
  my $tt = Template->new();
  my $template = q[root/src/ui_checks/qX_yield.tt2];
  my $output = q[];
  $tt->process($template, {}, \$output);

  ok(!$tt->error(), 'template processed OK');
}

1;
