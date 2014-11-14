use strict;
use warnings;
use Template;
use Template::Plugin::Number::Format;
use Test::More tests => 2;
use Cwd qw(cwd);
use File::Spec::Functions qw(catfile);


{
  my $wd = cwd;
  
  my $tt = Template->new({
    INCLUDE_PATH => [
               catfile($wd, q[root], q[src]),
               catfile($wd, q[root], q[src], q[ui_lanes])
                    ],
                        });

  my $template = q[library_lanes.tt2];
  my $output = q[];
  ok($tt->process($template, {}, \$output), 'template processing with no input');
  ok(!$tt->error(), 'no error in processing');
}
