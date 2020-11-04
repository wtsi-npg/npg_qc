package npg_qc::mqc::skipper;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Try::Tiny;
use List::MoreUtils qw/uniq/;

use npg_tracking::illumina::runfolder;
use WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::qc_store;
use npg_qc::autoqc::qc_store::options qw/ $PLEXES /;
use npg_qc::autoqc::db_loader;
use npg_qc::mqc::outcomes;
use npg_qc::mqc::outcomes::keys qw/ $SEQ_OUTCOMES /;

our $VERSION = '0';

Readonly::Scalar my $HUNDRED      => 100;
Readonly::Scalar my $USER_NAME    => 'pipeline';
Readonly::Scalar my $CHECK_NAME   => 'review';
Readonly::Scalar my $OUTCOME_TYPE => 'mqc_outcome';
Readonly::Scalar my $LANE_OUTCOME => 'Accepted final';

has 'qc_schema' => (
  isa      => 'npg_qc::Schema',
  is       => 'ro',
  required => 1,
);

has 'mlwh_schema' => (
  isa      => 'WTSI::DNAP::Warehouse::Schema',
  is       => 'ro',
  required => 1,
);

has 'npg_tracking_schema' => (
  isa      => 'npg_tracking::Schema',
  is       => 'ro',
  required => 1,
);

has 'qc_fails_threshold' => (
  isa      => 'Num',
  is       => 'ro',
  required => 1,
);

has 'id_runs' => (
  isa      => 'ArrayRef',
  is       => 'ro',
  required => 1,
);

has 'logger' => (
  isa      => 'Log::Log4perl::Logger',
  is       => 'ro',
  required => 1,
);

sub select_runs {
  my $self = shift;

  my @ids = ();
  foreach my $id_run (@{$self->id_runs}) {
    my $skip = 0;
    try {
      $skip = $self->_can_skip_mqc4run($id_run);
    } catch {
      $self->logger->error($_);
    };
    $skip and push @ids, $id_run;
  }

  return @ids;
}

sub save_review_results {
  my ($self, @id_runs) = @_;

  my @ids = ();
  foreach my $id_run (@id_runs) {
    my $num_loaded = 0;
    try {
      my $ap = npg_tracking::illumina::runfolder->new(
        id_run              => $id_run,
        npg_tracking_schema => $self->npg_tracking_schema
      )->archive_path;
      my $loader = npg_qc::autoqc::db_loader->new(
        schema       => $self->qc_schema,
        check        => [$CHECK_NAME],
        id_run       => $id_run,
        archive_path => $ap,
	verbose      => 0
      );
      $num_loaded = $loader->load();
    } catch {
      $self->logger->error($_);
    };
    $num_loaded and push @ids, $id_run;
  }

  return @ids;
}

sub set_final_seq_outcomes {
  my ($self, @id_runs) = @_;

  my @ids = ();
  my $o = npg_qc::mqc::outcomes->new(qc_schema => $self->qc_schema);

  foreach my $id_run (@id_runs) {
    my @info = values %{$self->_sample_info->{$id_run}};
    my @positions = sort { $a <=> $b }
                    uniq
                    map { $_->{position} }
                    @info;
    my $outcomes = {};
    my $tag_info = {};
    try {
      for my $position (@positions) {
        my $key = join q[:], $id_run, $position;
        $outcomes->{$SEQ_OUTCOMES}->{$key} = {$OUTCOME_TYPE => $LANE_OUTCOME};
        my @tags = sort { $a <=> $b }
                   map  { $_->{tag_index} }
                   grep { $_->{position} == $position }
                   @info;
        $tag_info->{$key} = \@tags;
      }
      $o->save($outcomes, $USER_NAME, $tag_info);
      push @ids, $id_run;
    } catch {
      $self->logger->error($_);
    };
  }

  return @ids;
}

has '_sample_info' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__sample_info {
  my $self = shift;

  my $entity_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY;
  my $rs = $self->mlwh_schema->resultset('IseqProductMetric')
   ->search( {'me.id_run' => $self->id_runs,
              'iseq_flowcell.entity_type' => $entity_type},
             {join => [{'iseq_flowcell' => 'sample'}]} );
  my $info = {};
  while (my $row = $rs->next) {
    my $sample_type = $row->iseq_flowcell->sample->control_type;
    $sample_type ||= q[];
    $info->{$row->id_run}->{$row->id_iseq_product} =
      {sample_type => $sample_type,
       position    => $row->position,
       tag_index   => $row->tag_index};
  }

  return $info;
}

sub _can_skip_mqc4run {
  my ($self, $id_run) = @_;

  my $sample_info = $self->_sample_info->{$id_run};
  my $query = npg_qc::autoqc::qc_store::query->new(
             id_run              => $id_run,
	     db_qcresults_lookup => 0,
	     option              => $PLEXES,
             npg_tracking_schema => $self->npg_tracking_schema);
  my $collection = npg_qc::autoqc::qc_store->new(
    use_db      => 0,
    checks_list => [$CHECK_NAME])->load_from_staging($query);
  my $num_results = $collection->size;
  if ($num_results == 0) {
    $self->logger->warn("No autoqc review results retrieved for run $id_run");
    return;
  }
  my $num_expected = scalar keys %{$sample_info};
  if ($num_results != $num_expected) {
    $self->logger->error(
      "Number of autoqc review results retrieved for run ${id_run}: " .
      "expected - $num_expected, actual - $num_results");
    return;
  } else {
    $self->logger->info(
      "$num_results autoqc review results retrieved for run ${id_run}");
  }

  my @controls     = ();
  my $real_samples = {};
  foreach my $r ($collection->all) {
    # We need outcomes to be defined
    ($r->qc_outcome and $r->qc_outcome->{mqc_outcome}) or return;
    my $d = $r->composition->digest;
    if (not exists $sample_info->{$d}) {
      $self->logger->error('No sample info for ' . $r->composition->freeze);
      return;
    }
    if ($sample_info->{$d}->{sample_type}) {
      push @controls, $r;
    } else {
      push @{$real_samples->{$sample_info->{$d}->{position}}}, $r;
    }
  }

  (@controls and keys %{$real_samples}) or return;

  my $has_failed = sub {
    my $r = shift;
    return npg_qc::Schema::Mqc::OutcomeDict
      ->is_rejected_outcome_description($r->qc_outcome->{mqc_outcome});
  };

  # Not fast-tracking if one or more positive or negative controls
  # fails across all lanes of a run.
  my @failed = grep { $has_failed->($_) } @controls;
  if (@failed) {
    $self->logger->info("At least one of the controls failed in run $id_run");
    return;
  }

  # Not fast-tracking if the threshold of failed samples is exceeded
  # in one of the lanes.
  foreach my $lane (keys %{$real_samples}) {
    my $samples = $real_samples->{$lane};
    @failed = grep { $has_failed->($_) } @{$samples};
    my $num_total  = @{$samples};
    my $num_failed = @failed;
    $self->logger->info(sprintf 'Run %i lane %i: failed %i real samples out of %i',
                                $id_run, $lane, $num_failed, $num_total);
    ( ($num_failed/$num_total) * $HUNDRED <= $self->qc_fails_threshold ) or return;
  }

  return 1; # Got to the end - fine to fast-track.
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::mqc::skipper

=head1 SYNOPSIS

=head1 DESCRIPTION

Helper class for the npg_mqc_skipper script.

=head1 SUBROUTINES/METHODS

=head2 qc_schema

DBIx schema object for the QC database, required attribute.

=head2 mlwh_schema

DBIx schema object for the mlwh database, required attribute.

=head2 npg_tracking_schema

DBIx schema object for the tracking database, required attribute.

=head2 qc_fails_threshold

QC fails threshold, percents, required attribute.

=head2 id_runs

An original array of run ids to consider, required attribute.

=head2 logger

Log::Log4perl::Logger logger object, required attribute.

=head2 select_runs

Returns a subset list of run ids for runs, which can be advanced to the
archival stage bypassing the manual QC process.

=head2 save_review_results

Given a list of run ids, saves review results for this runs to the QC
database and returns a subset list of run ids, for which this operation was
successful.

=head2 set_final_seq_outcomes

Given a list of run ids, creates and saves final sequencing QC outcomes for
each lane of the given runs and returns a subset list of run ids, for which
this operation was successful. Saving a final sequencing QC outcome for a lane
automatically finalises preliminary library QC outcomes for all products in
the pool.  

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Try::Tiny

=item List::MoreUtils

=item npg_tracking::illumina::runfolder

=item WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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
