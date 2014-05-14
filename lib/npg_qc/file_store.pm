#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       9 August 2010
# Last Modified: $Date: 2014-03-12 09:06:00 +0000 (Wed, 12 Mar 2014) $
# Id:            $Id: file_store.pm 18173 2014-03-12 09:06:00Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/file_store.pm $
#

package npg_qc::file_store;

use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use File::Spec;
use Perl6::Slurp;
use File::Basename;
use Compress::Zlib;

use npg_qc::Schema;
use npg_common::fastqcheck;

with 'MooseX::Getopt';

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 18173 $ =~ /(\d+)/mxs; $r; };

Readonly::Scalar my $DEFAULT_EXTENSION   => q[.fastqcheck];
Readonly::Scalar our $TABLE_NAME         => q[Fastqcheck];
Readonly::Hash our %THRESHOLDS_DB => ( 20 => 'twenty', 25 => 'twentyfive', 30 => 'thirty', 35 => 'thirtyfive', 40 => 'forty',);
##no critic (Variables::ProhibitPunctuationVars RequireExtendedFormatting ProhibitEnumeratedClasses)
my $FILE_NAME_REG_EXP = qr/^(\d+)_(\d)(_\d|_t)?(_[a-z]+)?(#\d+)?\.fastqcheck$/sm;
##use critic

has 'path'            => (  isa         => 'ArrayRef',
                            is          => 'rw',
                            required    => 1,
                            documentation =>
  'a path to a directory with the files to be saved; multiple paths (an array) are accepted',
                         );

has 'schema' =>    ( isa        => 'npg_qc::Schema',
                     is         => 'ro',
                     required   => 0,
                     lazy_build => 1,
                   );

has 'table_name' => ( isa        => 'Str',
                      is         => 'ro',
                      required   => 0,
                      default    => $TABLE_NAME,
                    );

sub _build_schema {
  my $self = shift;
  return npg_qc::Schema->connect();
}

sub _get_files {
  my ($self) = @_;

  my @all_files = ();
  foreach my $path (@{$self->path}) {
    my @files = glob File::Spec->catfile($path, q[*] . $DEFAULT_EXTENSION);
    if (@files) {
      push @all_files, @files;
    }
  }
  return \@all_files;
}

sub _qvalues {
  my ($values, $content) = @_;
  my @tholds = sort { $a <=> $b } keys %THRESHOLDS_DB;
  my $qvalues = npg_common::fastqcheck->new(file_content => $content)->qx_yield(\@tholds);
  my $i = 0;
  foreach my $thold (@tholds) {
    $values->{ $THRESHOLDS_DB{$thold} } = $qvalues->[$i];
    $i++;
  }
  return;
}

sub fname2ids {
  my $fname = shift;

  my ($id_run, $position, $read, $split, $tag_index) = $fname =~ $FILE_NAME_REG_EXP;
  if (!$id_run) {
    croak "Cannot infer id_run from filename $fname";
  }
  if (!$position) {
    croak "Cannot infer position from filename $fname";
  }

  if (!$read || $read eq '_1') {
    $read = 'forward';
  } elsif ($read eq '_2') {
    $read = 'reverse';
  } elsif ($read eq '_t') {
    $read = 'index';
  } else {
    croak "Unknown read type $read in $fname";
  }

  my $ids = {id_run => $id_run, position => $position, section => $read,};
  if (defined $tag_index) {
    $tag_index =~ s/^\#//smx;
    $ids->{tag_index} = $tag_index;
  }
  if ($split) {
    $split =~ s/^_//smx;
    $ids->{split} = $split;
  }

  return $ids;
}

sub save_files {
  my $self = shift;

  my $count = 0;
  my $rs = $self->schema->resultset($self->table_name);
  foreach my $file (@{$self->_get_files}) {
    my $transaction = sub {
      my ($fname, $dir, $ext) = fileparse($file);
      my $values = fname2ids($fname);

      my $content = slurp $file;
      $values->{file_content} = $content;
      $values->{file_name} = $fname;
      $values->{file_content_compressed} = compress($content);
      _qvalues($values, $content);
      $rs->find_or_new($values)->set_inflated_columns($values)->update_or_insert();
		          };
    eval {
      $self->schema->txn_do($transaction);
      $count++;
      1;
    } or do {
      croak "Failed to load $file to the database: $EVAL_ERROR";
    };
  }
  return $count;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::file_store

=head1 VERSION

$Revision: 18173 $

=head1 SYNOPSIS

 npg_qc::file_store->new(path => ['path1', 'path2'])->save_files();

=head1 DESCRIPTION

Saves into a database fastqcheck files found in the given paths. Also saves a numver of qX values.

=head1 SUBROUTINES/METHODS

=head2 path - an attribute; a reference to an array of paths where the files to be saved are located

=head2 save_files 

=head2 schema - an attribute; DBIx schema object for the NPG QC database

=head2 save_files - finds fastqcheck files in the given paths, reads the content and loads in to NPG QC database

=head2 fname2ids

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Moose
MooseX::Getopt
Carp
English qw{-no_match_vars}
File::Spec
Perl6::Slurp
File::Basename
npg_qc::Schema

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia, E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
