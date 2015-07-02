#########
# Author:        gq1
# Created:       2010-02-19
#
package npg_qc::illumina::loader::Runinfo;

use Moose;
use namespace::autoclean;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use Perl6::Slurp;

extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader::Runinfo

=head1 SYNOPSIS

=head1 DESCRIPTION

This module read the runinfo file and save the xml contents into the database

=head1 SUBROUTINES/METHODS

=head2 file_name

run recipe file name
 
=cut
has 'file_name'    => (isa           => q{Str},
                       is            => q{rw},
                       lazy_build    => 1,
                       documentation => q{runinfo file name},
                      );

sub _build_file_name {
  my $self = shift;
  return $self->runfolder_path.q{/RunInfo.xml};
}

=head2 _build_runlist_db

lazy build method

id_run list already in the database
 
=cut

sub _build_runlist_db {
   my $self = shift;
   my @list = $self->schema->resultset('RunInfo')
         ->search(undef,{columns => [qw/id_run/],});
   my %runlist = map { $_->id_run() => 1; } @list;
   return \%runlist;
}

=head2 run

loads one run information

=cut

sub run {
  my ($self) = @_;

  if(! -e $self->file_name() ){
     $self->mlog('There is no RunInfo.xml for run '.$self->id_run() );
     return;
  }

  my $file_content = slurp $self->file_name();
  $self->schema->resultset('RunInfo')->update_or_create({
                                         id_run        => $self->id_run(),
                                         run_info_xml  => $file_content,
                                      });
  return;
}

=head2 run_all

loads information for all eligible runs

=cut
sub run_all {
  my $self = shift;

  $self->mlog('Finding runfolder with RunInfo.xml file and load them into QC database');
  $self->mlog('There are '. (scalar keys %{$self->runfolder_list_todo}) .' runs to do' );
  foreach my $id_run ( keys %{$self->runfolder_list_todo}){
     my $loader = __PACKAGE__->new({
                            runfolder_path => $self->runfolder_list_todo->{$id_run},
                            schema         => $self->schema,
                            id_run         => $id_run,
                            });
     eval{
       $loader->run();
       1;
     } or do {
       $self->mlog($EVAL_ERROR);
     };
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

=item namespace::autoclean

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=item Perl6::Slurp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

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
