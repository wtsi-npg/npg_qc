#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-12
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#
package t::util;
use strict;
use warnings;
use Carp;
use DateTime;
use English qw(-no_match_vars);
use Test::More;
use HTML::PullParser;
use YAML qw(LoadFile);
use MIME::Parser;
use MIME::Lite;
use XML::Simple qw(XMLin);
use Data::Dumper;

use base qw(npg_qc::util);
use t::dbh;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

$ENV{HTTP_HOST}     = 'test.npg.com';
$ENV{DOCUMENT_ROOT} = './htdocs';
$ENV{SCRIPT_NAME}   = '/cgi-bin/npg_qc';
$ENV{dev}           = 'test';

sub dbh {
  my ($self, @args) = @_;

  if($self->{fixtures}) {
    $self->{'dbh'} = $self->SUPER::dbh(@args);
  }
  $self->{'dbh'}->{PrintError} = 0;
  $self->{'dbh'}->{PrintWarn} = 0;
  $self->{'dbh'} ||= t::dbh->new({'mock'=>$self->{'mock'}});
  return $self->{'dbh'};
}

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if($self->{fixtures}) {
    $self->load_fixtures();
  }

  return $self;
}

sub load_fixtures {
  my $self = shift;

  if($self->dbsection() ne 'test') {
    croak "dbsection is set to @{[$self->dbsection()]} which is not the same as 'test'. Refusing to go ahead!";
  }

  #########
  # build table definitions
  #
  if(!-e "data/schema.txt") {
    croak "Could not find data/schema.txt";
  }

  $self->log('Loading data/schema.txt');

  my $cmd = q(cat data/schema.txt | mysql);
  my $local_socket = $self->dbhost() eq 'localhost' && $ENV{'MYSQL_UNIX_PORT'} ? $ENV{'MYSQL_UNIX_PORT'} : q[];
  if ($local_socket) {
    $cmd .= q( --no-defaults); #do not read ~/.my.cnf
                               #this should be the first option
  }

  $cmd .= sprintf q( -u%s %s -D%s),
                 $self->dbuser(),
		 $self->dbpass()?"-p@{[$self->dbpass()]}":q(),
		 $self->dbname();

  if ($local_socket) {
    $cmd .= qq( --socket=$local_socket);
  } else {
    $cmd .= ' -h' . $self->dbhost() . ' -P' . $self->dbport();
  }

  $self->log("Executing: $cmd");
  open my $fh, q(-|), $cmd or croak $ERRNO;
  while(<$fh>) {
    print;
  }
  close $fh or croak $ERRNO;

  #########
  # populate test data
  #
  $self->log('Loading fixtures');

  opendir my $dh, q(t/data/fixtures) or croak "Could not open t/data/fixtures";
  my @fixtures = sort grep { /\d+\-[a-z\d_]+\.yml$/mix } readdir $dh;
  closedir $dh;

  my $dbh = $self->dbh();
  for my $fx (@fixtures) {
    my $yml     = LoadFile("t/data/fixtures/$fx");
    my ($table) = $fx =~ /\-([a-z\d_]+)/mix;
    $self->log("+- Loading $fx into $table");
    my $row1    = $yml->[0];
    my @fields  = keys %{$row1};
    my $query   = qq(INSERT INTO $table (@{[join q(, ), @fields]}) VALUES (@{[join q(,), map { q(?) } @fields]}));

    for my $row (@{$yml}) {
      $dbh->do($query, {}, map { $row->{$_} } @fields);
    }
    $dbh->commit();
  }

  return;
}

sub rendered {
  my ($self, $tt_name) = @_;
  local $RS = undef;
  open my $fh, q(<), $tt_name or croak "Error opening $tt_name: $ERRNO";
  my $content = <$fh>;
  close $fh or croak "Error closing $tt_name: $ERRNO";
  return $content;
}

sub test_rendered {
  my ($self, $chunk1, $chunk2) = @_;

  if(!$chunk1) {
    diag q(No chunk1 in test_rendered);
  }

  if(!$chunk2) {
    diag q(No chunk2 in test_rendered);
  }

  if($chunk2 =~ m{^t/}mx) {
    $chunk2 = $self->rendered($chunk2);

    if(!length $chunk2) {
      diag("Zero-sized $chunk2. Expected something like\n$chunk1");
    }
  }

  my $chunk1els = $self->parse_html_to_get_expected($chunk1);
  my $chunk2els = $self->parse_html_to_get_expected($chunk2);
  my $pass      = $self->match_tags($chunk2els, $chunk1els);

  if($pass) {
    return 1;

  } else {
    my ($fn) = $chunk2 =~ m{([^/]+)$}mx;
    $fn     .= q(-);
    open my $fh1, q(>), "/tmp/${fn}chunk1" or croak "Error opening /tmp/${fn}chunk1";
    open my $fh2, q(>), "/tmp/${fn}chunk2" or croak "Error opening /tmp/${fn}chunk2";
    print $fh1 $chunk1;
    print $fh2 $chunk2;
    close $fh1 or croak "Error closing /tmp/${fn}chunk1";
    close $fh2 or croak "Error closing /tmp/${fn}chunk2";
    diag("diff /tmp/${fn}chunk1 /tmp/${fn}chunk2");
  }

  return;
}

sub parse_html_to_get_expected {
  my ($self, $html) = @_;
  my $p;
  my $array = [];

  if ($html =~ m{^t/}xms) {
    $p = HTML::PullParser->new(
			       file  => $html,
			       start => '"S", tagname, @attr',
			       end   => '"E", tagname',
			      );
  } else {
    $p = HTML::PullParser->new(
			       doc   => $html,
			       start => '"S", tagname, @attr',
			       end   => '"E", tagname',
			      );
  }

  my $count = 1;
  while (my $token = $p->get_token()) {
    my $tag = q{};
    for (@{$token}) {
      $_ =~ s/\d{4}-\d{2}-\d{2}/date/xms;
      $_ =~ s/\d{2}:\d{2}:\d{2}/time/xms;
      $tag .= " $_";
    }
    push @{$array}, [$count, $tag];
    $count++;
  }

  return $array;
}

sub match_tags {
  my ($self, $expected, $rendered) = @_;
  my $fail = 0;
  my $a;

  for my $tag (@{$expected}) {
    my @temp = @{$rendered};
    my $match = 0;
    for ($a= 0; $a < @temp;) {
      my $rendered_tag = shift @{$rendered};
      if ($tag->[1] eq $rendered_tag->[1]) {
        $match++;
        $a = scalar @temp;
      } else {
        $a++;
      }
    }

    if (!$match) {
      diag("Failed to match '$tag->[1]'");
      return 0;
    }
  }

  return 1;
}

###########
# for catching emails, so firstly they don't get sent from within a test
# and secondly you could then parse the caught email
#

sub catch_email {
  my ($self, $model) = @_;
  my $sub = sub {
		 my $msg = shift;
        	 push @{$model->{emails}}, $msg->as_string;
		 return;
	        };
  MIME::Lite->send('sub',$sub);
  return;
}

##########
# for parsing emails to get information from them, probably caught emails
#

sub parse_email {
  my ($self, $email) = @_;
  my $parser = MIME::Parser->new();
  $parser->output_to_core(1);
  my $entity = $parser->parse_data($email);
  $self->{email_annotation} = $entity->bodyhandle->as_string();
  $self->{email_subject} = $entity->head->get('Subject',0);
  $self->{email_to} = $entity->head->get('To',0);
  $self->{email_bcc} = $entity->head->get('Bcc',0);
  $self->{email_from} = $entity->head->get('From',0);
  return;
}

sub is_rendered_xml {

  my ($str, $fn, @args) = @_;
  my ($received, $expected);

  $str ||= q[];

  if($str =~ /Content-type/smix) {
    #########
    # Response headers have no place in a xml parser
    #
    $str =~ s/.*?\n\n//smx;
  }

  eval {
    $received = XMLin($str);
  } or do {
    croak qq[Failed to parse received XML:\n].$str;
  };

  eval {
    if($fn =~ /</mx) {
      $expected = XMLin($fn);
    } else {
      if (-e $fn) {
        $expected = XMLin("$fn");
      } else {
        croak qq[Failed to parse expected XML in file $fn];
      }
    }
  } or do {
    croak q[Failed to parse expected XML];
  };

  my $result = Test::More::is_deeply($received, $expected, @args);
  if(!$result) {
    carp "RECEIVED: ".Dumper($received);
    carp "EXPECTED: ".Dumper($expected);
  }
  return $result;
}

1;
