package npg_qc::autoqc::checks::genotype_call;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use JSON;
use Readonly;
use IO::All;
use Try::Tiny;


extends qw(npg_qc::autoqc::checks::check);

with qw(npg_tracking::data::gbs_plex::find
        npg_common::roles::software_location
        npg_qc::utils::genotype_calling);

our $VERSION = '0';

Readonly::Array  my @CALLING_METRICS  => qw[sex_markers_attempted sex_markers_called sex_markers_passed genotypes_attempted genotypes_called genotypes_passed];

Readonly::Scalar my $DEFAULT_PASS_CALL_RATE  => 0.7;

has '+file_type' => (default => q[cram],);

has 'calling_metrics_fields' => (
  is       => q[ro],
  isa      => 'ArrayRef[Str]',
  default  => sub { \@CALLING_METRICS },
  init_arg => undef,
);

has 'pass_call_rate' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_pass_call_rate],
);
sub _build_pass_call_rate {
  my ($self) = shift;
  return $self->genotype_info->{'pass_call_rate'} // $DEFAULT_PASS_CALL_RATE;
}

has 'genotype_info' => (
  is       => q[ro],
  isa      => q[HashRef],
  lazy     => 1,
  builder  => q[_build_genotype_info],
  init_arg => undef,
);
sub _build_genotype_info {
  my ($self) = shift;
  my $info = {};
  if($self->gbs_plex_info_path){
     $info = decode_json(io($self->gbs_plex_info_path)->slurp);
  }
  return $info;
}

has 'annotation_path' => (
  is       => q[ro],
  isa      => q[Str | Undef],
  lazy     => 1,
  builder  => q[_build_annotation_path],
  init_arg => undef,
);
sub _build_annotation_path {
  my $self = shift;
  return $self->gbs_plex_annotation_path;
}

has 'ploidy_path' => (
  is       => q[ro],
  isa      => q[Str | Undef],
  lazy     => 1,
  builder  => q[_build_ploidy_path],
  init_arg => undef,
);
sub _build_ploidy_path {
  my $self = shift;
  return $self->gbs_plex_ploidy_path;
}


override 'can_run' => sub {
  my $self = shift;

  if(!$self->gbs_plex_name) {
    $self->result->add_comment('No gbs_plex_name is defined');
    return 0;
  }
  if (!$self->lims->sample_name) {
    $self->result->add_comment('Can only run on a single sample');
    return 0;
  }

  return 1;
};


override 'execute' => sub {
  my ($self) = @_;

  super();

  if(!$self->can_run()) {
    return 1;
  }

  $self->result->gbs_plex_name($self->gbs_plex_name);
  $self->result->gbs_plex_path($self->annotation_path);
  $self->result->set_info('Caller',$self->bcftools);
  $self->result->set_info('Criterion',
           q[Genotype passed rate >= ]. $self->pass_call_rate);

  try {
    $self->run_calling;

    (($self->result->genotypes_passed/
     $self->result->genotypes_attempted) >= $self->pass_call_rate) ?
     $self->result->pass(1) : $self->result->pass(0);

    1;
  } catch {
    croak qq[ERROR calling genotypes : $_];
  };

  $self->result->add_comment(join q[ ], $self->messages->messages);

  return 1;
};


__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

    npg_qc::autoqc::checks::genotype_call

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::genotype_call;

=head1 DESCRIPTION

    Call genotypes in gbs_plex data

=head1 SUBROUTINES/METHODS

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

=item English

=item Carp

=item JSON

=item Readonly

=item IO::All

=item Try::Tiny

=item npg_tracking::data::gbs_plex::find

=item npg_common::roles::software_location

=item npg_qc::utils::genotype_common

=back

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
