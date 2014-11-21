use strict;
use warnings;
use Template;
use Template::Plugin::Number::Format;
use Test::More tests => 1;

{
  my $tt = Template->new();
  my $template = q[root/src/ui_lanes/lane.tt2];
  my $output = q[];
  $tt->process($template, {}, \$output);

  ok(!$tt->error(), 'template processed OK');
}

1;
