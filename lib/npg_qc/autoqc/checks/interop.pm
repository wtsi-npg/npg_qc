package npg_qc::autoqc::checks::interop;

use Moose;
use namespace::autoclean;
use Class::Load qw(load_class);
use Carp;

use npg_qc::illumina::interop::parser;
use npg_qc::autoqc::results::interop;
extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::interop

=head1 SYNOPSIS

Multiple ways of creating the check object:

  # multiple output directories should be given
  # as an array
  my $i = npg_qc::autoqc::checks::interop->(
    qc_in => 'interop_dir_path', rpt_list => '33:1;33:2',
    qc_out => [qw/dir_out1 dir_out2/]
  );
  # a single output directory can be given as a string
  $i = npg_qc::autoqc::checks::interop->(
    qc_in => 'interop_dir_path', rpt_list => '33:1',
    qc_out => 'dir_out'
  );

  # when rpt_list is not supplied, qc_in should be the
  # run folder path; use a single output directory
  $i = npg_qc::autoqc::checks::interop->(
    qc_in => 'runfolder_path', id_run => 33,
    qc_out => 'dir_out' 
  );
  $i = npg_qc::autoqc::checks::interop->(
    qc_in => 'runfolder_path', qc_out => 'dir_out'
  );

Then execute the check and inspect the results. 
 
  $i->execute();
  for my $result (@{$i->result}) {
    # do something for each
    # npg_qc::autoqc::results::interop object
  }

Or run the check and the results will be serialized
to output directories (or directory).
  
  $i->run();

=head1 DESCRIPTION

This check extracts a number of metrics from Illumina InterOp files
and saves the results in per-lane result objects. When run within
the pipeline's autoqc framework, multiple lane-level result JSON
files are produced.

=head1 SUBROUTINES/METHODS

=cut

=head2 rpt_list

Semi-colon separated list of run:position values.
This attribute is optional. If not given, an attempt to build it
will be made, in which case run id and number of lanes is needed.
If id_run attribute is defined, if is used, otherwise it is inferred.
Number of lanes is inferred as well. Access to tracking database
and presence of RunInfo.xml and RunParameters.xml files is required
for the build.

=cut

has '+rpt_list' => (
  builder => '_build_rpt_list_from_run_info',
);
sub _build_rpt_list_from_run_info {
  my $self = shift;

  for my $class (qw/
    npg_tracking::Schema
    npg_tracking::illumina::runfolder
    npg_tracking::glossary::rpt         
                   /) {
    load_class($class) or croak "Failed to load class $class";
  }

  # We assume that qc_in in this case is runfolder path
  $self->_set_path_name('runfolder_path');

  my $rf = npg_tracking::illumina::runfolder->new(
    runfolder_path      => $self->qc_in,
    npg_tracking_schema => $self->_npg_tracking_schema
  );
  my $id_run = $self->id_run;
  $id_run ||= $rf->id_run();
  return npg_tracking::glossary::rpt->deflate_rpts([
    (map { {id_run => $id_run, position => $_} } (1 .. $rf->lane_count()))
  ]);
}

=head2 result

An array of npg_qc::autoqc::results::interop result objects,
each object corresponds to one of the components of the
composition object for the check object.

=cut

has '+result' => (
  isa       => 'ArrayRef[npg_qc::autoqc::results::interop]',
  metaclass => 'NoGetopt',
);
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
    ->new($self->_get_path_name => $self->qc_in)->parse();
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

has '_path_name' => (
  isa       => 'Str',
  is        => 'ro',
  required  => 0,
  init_arg  => undef,
  default   => 'interop_path',
  writer    => '_set_path_name',
  reader    => '_get_path_name',
);

has '_npg_tracking_schema' => (
  isa        => 'Maybe[npg_tracking::Schema]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__npg_tracking_schema {
  my $self = shift;
  return npg_tracking::Schema->connect();
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

=item npg_tracking::Schema

=item npg_tracking::illumina::runfolder

=item npg_tracking::glossary::rpt  

=back

=head1 AUTHOR

Steven Leonard
Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019,2020 Genome Research Ltd.

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
