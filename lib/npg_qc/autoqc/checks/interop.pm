package npg_qc::autoqc::checks::interop;

use Moose;
use namespace::autoclean;
use Carp;

use npg_qc::illumina::interop::parser;
use npg_qc::autoqc::results::interop;
extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::interop

=head1 SYNOPSIS

=head1 DESCRIPTION

This check extracts a number of metrics from Illumina InterOp files
and save the results in per-lane result objects. When run within
the autoqc framework, multiple lane-level result JSON files are
produced.

=head1 SUBROUTINES/METHODS

=cut

=head2 result

An array of npg_qc::autoqc::results::interop result objects,
each object corresponds to one of the components of the
composition object for the check object.

=cut

has '+result' => (isa => 'ArrayRef[npg_qc::autoqc::results::interop]',);
sub _build_result {
  my $self = shift;
  my @results = ();
  my $class_name     = ref $self;
  my $module_version = $VERSION;
  my $parser         = 'npg_qc::illumina::interop::parser';
  my $parser_version = $npg_qc::illumina::interop::parser::VERSION;
  foreach my $c ($self->composition->components_list) {
    my $composition = npg_tracking::glossary::composition->new(components => [$c]);
    my $r = npg_qc::autoqc::results::interop->new(
              rpt_list    => $composition->freeze2rpt,
              composition => $composition
            );
    $r->set_info('Check', $class_name);
    $r->set_info('Check_version', $module_version);
    $r->set_info('Custom_parser', $parser);
    $r->set_info('Custom_parser_version', $parser_version);
    push @results, $r;
  }
  return \@results;
}

=head2 qc_in

Directory where Illumina InterOp files are, required argument,
directory should exist.

=cut

has '+qc_in' => ( required   => 1, );

=head2 execute

This method executes the check and creates result objects. It
does not extend the parent's execute method in order to avoid
building an array of input files, which is not needed for this
check.

=cut

sub execute {
  my $self = shift;

  $self->has_filename_root and carp
    'filename_root is set, but will be disregarded';

  my $metrics = npg_qc::illumina::interop::parser
    ->new(interop_path => $self->qc_in)->parse();
  my $lane_metrics = {};

  while (my ($key, $m) = each %{$metrics}) {
    foreach my $position (keys %{$m}) {
      $lane_metrics->{$position}->{$key} = $m->{$position};
    }
  }

  my @errors = ();
  foreach my $r (@{$self->result}) {
    my $position = $r->composition->get_component(0)->position;
    if ($lane_metrics->{$position}) {
      $r->metrics($lane_metrics->{$position});
    } else {
      push @errors, "No data available for lane $position";
    }
  }
  @errors and croak 'ERROR: ' . join qq[\n], @errors;

  return;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item npg_qc::illumina::interop::parser

=back

=head1 AUTHOR

Steven Leonard
Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 GRL

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
