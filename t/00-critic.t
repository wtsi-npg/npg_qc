#########
# Author:        rmp
# Last Modified: $Date: 2007-07-16 14:19:11 +0100 (Mon, 16 Jul 2007) $ $Author: rmp $
# Id:            $Id: 00-critic.t 155 2007-07-16 13:19:11Z rmp $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-critic.t,v $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/00-critic.t $
#
package critic;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

our $VERSION = do { my @r = (q$Revision: 155 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

if (!$ENV{TEST_AUTHOR}) {
  my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
  plan( skip_all => $msg );
}

eval {
  require Test::Perl::Critic;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Perl::Critic not installed';
} else {
  Test::Perl::Critic->import(
			   -severity => 1,
			   -exclude  => [ 'tidy',
                             'ValuesAndExpressions::ProhibitImplicitNewlines',
                             'ValuesAndExpressions::RequireConstantVersion',
                             'Documentation::PodSpelling',
                             'Subroutines::ProhibitUnusedPrivateSubroutines',
                             'ProhibitEscapedMetacharacters',
                             'ProhibitUnrestrictedNoCritic',
                            ],
               -profile  => 't/perlcriticrc',
               -verbose => "%m at %f line %l, policy %p\n",
			    );

  all_critic_ok();
}

1;
