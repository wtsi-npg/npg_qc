#########
# Author:        gq1
# Created:       2010-02-19
#
package npg_qc::illumina::loader::Recipe;

use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use File::Basename;
use Perl6::Slurp;
use Digest::MD5 qw(md5 md5_hex);

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Recipe

=head1 SYNOPSIS

=head1 DESCRIPTION

This module read the recipe xml file and tile layout txt fiel under Config directory
to populate two tables run_recipe an reciep_file

=head1 SUBROUTINES/METHODS

=head2 file_name

run recipe file name
 
=cut
has 'file_name'    => (isa           => q{Str},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{run recipe file name},
                      );

sub _build_file_name {

  my $self = shift;
  my @files = glob $self->runfolder_path.q{/Recipe*.xml};
  if(scalar @files != 1){
    $self->mlog( q{No Recipe file or there are more than one Recipe xml available:}.$self->runfolder_path );
    return q{};
  }

  return $files[0];
}

=head2 _build_runlist_db

lazy build method

id_run list already in the database
 
=cut

sub _build_runlist_db {
   my $self = shift;
   my @list = $self->schema->resultset('RunRecipe')
         ->search(undef,{columns => [qw/id_run/],});
   my %runlist = map { $_->id_run() => 1; } @list;
   return \%runlist;
}

=head2 run

loads one run recipe

=cut

sub run {
  my ($self) = @_;
  my $transaction = sub { $self->_read_run_recipe() };
  $self->schema->txn_do($transaction);
  return;
}


sub _read_run_recipe {
    my ($self) = @_;

    my $cycle_count = $self->cycle_count();
    my $tile_count = $self->tile_count();
    my $lane_count = $self->lane_count();

    my $col_count = 0;
    eval{
        $col_count= $self->tilelayout_columns();
        1;
    } or do {
        $self->mlog($EVAL_ERROR);
    };

    my $cycle_read1;
    my @read1_cycle_range = $self->read1_cycle_range();
    if(scalar @read1_cycle_range == 2){
       $cycle_read1 = $read1_cycle_range[1] - $read1_cycle_range[0] + 1;
    }

    my $cycle_read2;
    my @read2_cycle_range = $self->read2_cycle_range();
    if(scalar @read2_cycle_range == 2){
       $cycle_read2 = $read2_cycle_range[1] - $read2_cycle_range[0] + 1;
    }

    my $first_indexing_cycle_number;
    my $last_indexing_cycle_number;

    my @read_index_cycle_range = $self->indexing_cycle_range();
    if(scalar @read_index_cycle_range == 2){
       $first_indexing_cycle_number = $read_index_cycle_range[0];
       $last_indexing_cycle_number  = $read_index_cycle_range[1];
    }

    my $id_recipe_file;

    if(-e $self->file_name()){

        my $xml = slurp $self->file_name();
	my $md5 = md5_hex($xml);

        my $recipe_file_fields = {
               file_name   => basename($self->file_name()),
               md5         => $md5,
               xml         => $xml,
           };

        my $recipe_file_obj = $self->schema->resultset('RecipeFile')->update_or_create( $recipe_file_fields );
	$id_recipe_file = $recipe_file_obj->id_recipe_file();
    }

    my $run_recipe_fields = {
               id_run               => $self->id_run(),
               cycle                => $cycle_count,
               lane                 => $lane_count,
               tile                 => $tile_count,
               col                  => $col_count,
               first_indexing_cycle => $first_indexing_cycle_number,
               last_indexing_cycle  => $last_indexing_cycle_number,
               cycle_read1          => $cycle_read1,
               cycle_read2          => $cycle_read2,
               id_recipe_file       => $id_recipe_file,
             };
    $self->schema->resultset('RunRecipe')->update_or_create( $run_recipe_fields );
    return;
}

=head2 run_all

loads recipes for all eligible runs
 
=cut
sub run_all {
  my $self = shift;
  $self->mlog('Finding runfolder with recipe information and load them into QC database');
  $self->mlog('There are '. ( scalar keys %{$self->runfolder_list_todo} ).' runs to do' );
  foreach my $id_run (sort {$a <=> $b} keys %{$self->runfolder_list_todo}) {
    eval {
       __PACKAGE__->new( runfolder_path => $self->runfolder_list_todo->{$id_run},
                         schema         => $self->schema,
                         id_run         => $id_run,
                       )->run();
      1;
    } or do {
      $self->mlog($EVAL_ERROR);
    };
  }
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=item File::Basename

=item Perl6::Slurp

=item Digest::MD5

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Guoying Qi (gq1@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
