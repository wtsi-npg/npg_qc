package npg_qc::illumina::loader::base;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use XML::LibXML;

use npg_qc::Schema;
use npg_tracking::Schema;

with qw{npg_tracking::illumina::run::short_info
        npg_tracking::illumina::run::folder};
with qw{npg_tracking::illumina::run::long_info};

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::base

=head1 SYNOPSIS

  my $oDerived = npg_qc::illumina::loader::<derived_class>->new(
    verbose    => 1,
    run_folder => $sRunFolder,
  );

id_run or run_folder must be provided, or one of runfolder-related paths
verbose turns on the optional logs

=head1 DESCRIPTION

A base class object for loader object modules.

=head1 SUBROUTINES/METHODS

=head2 verbose

Boolean to be set on object creation

=cut

has q{verbose} => (isa => q{Bool},
                   is  => q{ro}
                  );

sub _build_run_folder {
  my ($self) = @_;
  my @temp = split m{/}xms, $self->runfolder_path();
  return pop @temp;
}

=head2 schema

create an ojbect of dbix class schema for QC database

=cut

has q{schema} => (isa           => q{npg_qc::Schema},
                  is            => q{ro},
                  lazy_build    => 1,
                 );
sub _build_schema {
  return npg_qc::Schema->connect();
}

=head2 schema_npg_tracking

create an ojbect of dbix class schema for run tracking database

=cut

has q{schema_npg_tracking} => (isa        => q{npg_tracking::Schema},
                               is         => q{ro},
                               lazy_build => 1,
                              );
sub _build_schema_npg_tracking {
  return npg_tracking::Schema->connect();
}

=head2 runlist_db

id_run list already in the database

_build_runlist_db needed in the sub class
 
=cut
has 'runlist_db' => (is          => 'rw',
                     isa         => 'Maybe[HashRef]',
                     lazy_build  => 1,
                    );

=head2 runfolder_list_todo

run folder list with required file inside
 
=cut
has 'runfolder_list_todo' => (is          => 'rw',
                              isa         => 'HashRef',
                              lazy_build  => 1,
                             );
sub _build_runfolder_list_todo {
  my $self = shift;

  my %runfolder_list_todo = ();
  my $runfolder_list_in_staging = $self->runfolder_list_in_staging();
  my $runlist_db = $self->runlist_db();
  foreach my $id_run (keys %{$runfolder_list_in_staging}){
    if( !defined $runlist_db || !$runlist_db->{$id_run} ){
      $runfolder_list_todo{$id_run} = $runfolder_list_in_staging->{$id_run};
    }
  }

  return \%runfolder_list_todo;
}

=head2 runfolder_list_in_staging

get the runfolder list current in staging

=cut

sub runfolder_list_in_staging {
  my ($self) = @_;

  my $runfolder_list = {};
  my $staging_tag = $self->schema_npg_tracking->resultset( q(Tag) )->find( { tag => q{staging} } );
  my @runs = grep {$_} $staging_tag->runs();
  $self->mlog( scalar @runs . q{ runs with staging tag} );

  foreach my $run ( @runs ){
    my $folder_name = $run->folder_name();
    my $folder_path_glob = $run->folder_path_glob();
    my $id_run = $run->id_run();

    if( $folder_name && $folder_path_glob ){
      my @dir = glob qq{$folder_path_glob/$folder_name};
      @dir = grep {-d } @dir;

      my %fs_inode_hash; #ignore multiple paths point to the same folder
      @dir = grep { not $fs_inode_hash { join q(,), stat }++ } @dir;

      if( scalar  @dir != 1 ){
        $self->mlog("Run $id_run: no runfolder available or more than one available");
      }else{
        $runfolder_list->{$id_run} = $dir[0];
      }
    }
  }
  return $runfolder_list;
}


has q{parser} => (isa     => q{XML::LibXML},
                  is      => q{ro},
                  default => sub {return XML::LibXML->new()},
                 );

=head2 get_id_run_tile

given lane, tile and read number, find or create id_run_tile in the database 

=cut

sub get_id_run_tile {
  my ($self, $lane_number, $read_number, $tile_number) = @_;

  my $id_run = $self->id_run();
  my $schema = $self->schema();

  my $run_tile = $schema->resultset('RunTile')
                        ->find_or_create(
                            {id_run    => $id_run,
                             position  => $lane_number,
                             tile      => $tile_number,
                             end       => $read_number,
                            });

  return $run_tile->id_run_tile();
}

=head2 get_id_analysis

given lane, tile and read number, find or create id_run_tile in the database 

=cut
sub get_id_analysis {
  my ($self, $end) = @_;

  my $id_run = $self->id_run();
  my ($y, $m, $d) = $self->run_folder() =~ /(\d\d)(\d\d)(\d\d)_\w{2}\d+_\d+/mxs;
  if(!$y){
    ($y, $m, $d) = $self->run_folder() =~ /^(\d\d)-(\d\d)-(\d\d)_+/mxs;
  }
  my $date = sprintf q(%4d-%02d-%02d), $y+2000, $m, $d;## no critic (Policy::ValuesAndExpressions::ProhibitMagicNumbers)
  my $folder = $self->recalibrated_path();

  my $schema = $self->schema();

  my @current_analysis_per_run = $schema->resultset('Analysis')
                         ->search(
                            {id_run    => $id_run,
                             end       => $end,
                             iscurrent => 1,
                            });

  my @current_analysis_per_run_same_folder;

  foreach my $analysis (@current_analysis_per_run){
    if( $analysis->folder() eq $folder){
      push @current_analysis_per_run_same_folder, $analysis;
    } else {
      $analysis->update({iscurrent => 0});
    }
  }

  if(scalar @current_analysis_per_run_same_folder > 1){
    croak qq{More than one current rows found in analysis table for run $id_run, read $end, folder $folder};
  }elsif(scalar @current_analysis_per_run_same_folder == 1){
    return $current_analysis_per_run_same_folder[0]->id_analysis();
  }

  my $analysis = $schema->resultset('Analysis')
                        ->create(
                            {id_run    => $id_run,
                             end       => $end,
                             date      => $date,
                             folder    => $folder,
                             iscurrent => 1,
                            });

  return $analysis->id_analysis();
}

=head2 transfer_read_number

given read number for a multiplex run, transfer the read number 1->1, 2->t, 3->2
for non-indexing run, no change

=cut
sub transfer_read_number{
  my ($self, $read_number) = @_;

  if($read_number == 3){ ## no critic (Policy::ValuesAndExpressions::ProhibitMagicNumbers)
    $read_number = 2;
  }elsif($read_number == 2 && $self->is_indexed()){
    $read_number = q{t};
  }
  return $read_number;
}

=head2 mlog

message logging

=cut
sub mlog {
  my ($self, $message) = @_;
  if ($message) {
    warn "$message\n";
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English -no_match_vars

=item Readonly

=item XML::LibXML

=item npg_tracking::illumina::run::short_info

=item npg_tracking::illumina::run::long_info

=item npg_tracking::illumina::run::folder

=item npg_qc::Schema

=item npg_tracking::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown
Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
