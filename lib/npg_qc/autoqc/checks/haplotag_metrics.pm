
package npg_qc::autoqc::checks::haplotag_metrics;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use File::Spec::Functions qw(catfile);
use Readonly;
use st::api::lims;
use IPC::Open3 'open3';
local $SIG{CHLD} = 'IGNORE';

extends qw( npg_qc::autoqc::checks::check );

our $VERSION = '0';

Readonly::Scalar our $PASS_RATE => 0.8;
Readonly::Scalar our $FILE_EXT => q[SamHaplotag_Clear_BC];

has '_file_path_root' => ( isa        => 'Str',
                           is         => 'ro',
                           lazy_build => 1,);

sub _build__file_path_root {
  my $self = shift;
  my $path;
  if ($self->has_filename_root && $self->has_qc_in) {
    $path = catfile $self->qc_in, $self->filename_root;
  } else {
    ($path) = $self->input_files->[0] =~ /\A(.+)\..+\Z/smx;
  }

  return $path;
}

override 'can_run' => sub {
  my $self = shift;
  my $lims;
  if ($self->has_rpt_list) {
    $lims = st::api::lims->new(rpt_list => $self->rpt_list);
  } else {
    $lims = st::api::lims->new(id_run=>$self->id_run, position=>$self->position);
  }
  my $library_type = $lims->library_type;
  my $is_haplotag_lib = $library_type && ($library_type =~ /Haplotagging/smx);
  return $is_haplotag_lib;
};


override 'execute' => sub {
  my $self = shift;

  if (!$self->can_run()) {
    return 1;
  }

  super();

  my $clear_file = $self->_file_path_root . q[._SamHaplotag_Clear_BC];
  my $count;
  my ($writer, $reader, $err);
  open3($writer, $reader, $err, "wc -l $clear_file");
  $count = <$reader>;
  my ($clear_count) = $count =~ /(\d+)/smx;
  $clear_count ||= 1; $clear_count -= 1;

  my $unclear_file = $self->_file_path_root . q[._SamHaplotag_UnClear_BC];
  open3($writer, $reader, $err, "wc -l $unclear_file");
  $count = <$reader>;
  my ($unclear_count) = $count =~ /(\d+)/smx;
  $unclear_count ||= 1; $unclear_count -= 1;

  my $missing_file = $self->_file_path_root . q[._SamHaplotag_Missing_BC_QT_tags];
  open3($writer, $reader, $err, "wc -l $missing_file");
  $count = <$reader>;
  my ($missing_count) = $count =~ /(\d+)/smx;
  $missing_count ||= 1; $missing_count -= 1;

  $self->result->clear_file($clear_file);
  $self->result->unclear_file($unclear_file);
  $self->result->missing_file($missing_file);

  $self->result->clear_count($clear_count);
  $self->result->unclear_count($unclear_count);
  $self->result->missing_count($missing_count);

  my $pass = ($clear_count + $unclear_count) / ($clear_count + $unclear_count + $missing_count);
  $self->result->pass( ($pass > $PASS_RATE) ? 1: 0 );
  return;
};


__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::haplotag_metrics

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::haplotag_metrics;

=head1 DESCRIPTION
Metrics related to SamHaplotag


=head1 SUBROUTINES/METHODS


=head2 haplotag_metrics_file

=head2 execute


=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=back

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 GRL

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
