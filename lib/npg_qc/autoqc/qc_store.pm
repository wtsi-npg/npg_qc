#########
# Author:        Andy Brown ajb@sanger.ac.uk and Marina Gourtovaia mg8@sanger.ac.uk 
# Created:       Summer 2009
#

package npg_qc::autoqc::qc_store;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Carp;
use List::MoreUtils qw/any/;
use Readonly;

use npg_qc::Schema;
use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';

Readonly::Scalar my $NON_STORABLE_CHECK  => qr/rna_seqc/sm;

## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitManyArgs)

=head1 NAME

npg_qc::autoqc::qc_store

=head1 SYNOPSIS

=head1 DESCRIPTION

Transparent retrieval of stored auto QC data.
One instance of this class should be created by the application.

=head1 SUBROUTINES/METHODS

=cut

=head2 use_db

A boolean flag. If it is false, data will be retrieved from
the staging area only; no attempt to connect to the QC database
will be made. True by default.

=cut
has 'use_db'       => ( isa        => 'Bool',
                        is         => 'ro',
                        required   => 0,
                        default    => 1,
		      );

=head2 verbose

A boolean flag switching verbosity on and off, true by default.

=cut
has 'verbose'      => ( isa        => 'Bool',
                        is         => 'ro',
                        required   => 0,
                        default    => 1,
                      );

=head2 qc_schema

DBIx schema connection

=cut
has 'qc_schema'    => ( isa        => 'Maybe[npg_qc::Schema]',
                        is         => 'ro',
                        required   => 0,
                        lazy_build => 1,
		      );
sub _build_qc_schema {
  my $self = shift;
  if ($self->use_db) {
    return npg_qc::Schema->connect();
  }
  return;
}

sub _query_obj {
  my ($self, $id_run, $lanes, $what, $db_lookup, $npg_schema) = @_;

  my $obj_hash = { id_run => $id_run, npg_tracking_schema => $npg_schema, };
  if ($lanes) { $obj_hash->{positions} = $lanes; }
  if ($what) { $obj_hash->{option} = $what; }
  if (defined $db_lookup) { $obj_hash->{db_qcresults_lookup} = $db_lookup; }
  return npg_qc::autoqc::qc_store::query->new($obj_hash);
}

=head2 load_run

Data for a run returned as an npg_qc::autoqc::results::collection object.

=cut
sub load_run {
  my ($self, $id_run, $db_lookup, $lanes, $what) = @_;
  my $query = $self->_query_obj($id_run, $lanes, $what, $db_lookup);
  return $self->load($query);
}

=head2 load

Data for a query returned as an npg_qc::autoqc::results::collection object.

=cut
sub load {
  my ($self, $query) = @_;
  if (!defined $query) { croak q[Query object should be defined]; }
  my $collection;
  if ($self->use_db && $query->db_qcresults_lookup) {
    $collection = $self->run_from_db($query);
  }
  if ( !defined $collection || $collection->is_empty() ) {
    $collection = npg_qc::autoqc::results::collection->new();
    try {
      $collection->load_from_staging($query);
    } catch {
      if ($self->verbose) {
        carp qq[Error when loading autoqc results from staging: $_];
      }
    };
  }
  return $collection;
}

=head2 load_lanes

Data for a number of lanes returned as an npg_qc::autoqc::results::collection object.
The second argument is a reference to a hash defining the lanes. Run IDs should be
used as keys. A reference to an array with lane numbers should be used as values.

If npg_schema argument is undefined, stored globs will not be used.

=cut
sub load_lanes {
  my ($self, $run_lanes_hash, $db_lookup, $what, $npg_schema) = @_;

  my $collection =  npg_qc::autoqc::results::collection->new();
  foreach my $id_run (keys %{$run_lanes_hash}) {
    my $query = $self->_query_obj($id_run, $run_lanes_hash->{$id_run}, $what, $db_lookup, $npg_schema);
    $query->propagate_npg_tracking_schema(1);
    my $temp_collection = $self->load($query, $npg_schema);
    if ($temp_collection && $temp_collection->size > 0) {
      $collection->add($temp_collection->results);
    }
  }
  return $collection;
}


=head2 load_from_path

Reads all serialised result objects from a given path or a list of paths and returns them as 
an npg_qc::autoqc::results::collection object. The second argument is a reference
to an run id in the code of the caller. An id_run value is assigned to it.

=cut
sub load_from_path {
  my ($self, @path) = @_;
  if (!@path) {
    croak 'Path should be given';
  }
  my $c = npg_qc::autoqc::results::collection->new();
  foreach my $p (@path) {
    $c->add_from_dir($p);
  }
  return $c;
}

=head2 run_from_db

Retrieves a collection of DBIx result objects for a run. Query argument
(npg_qc::autoqc::qc_store::query object) should be supplied.
   
    my $store = npg_qc::autoqc::qc_store->new(use_db => 1);
    my $query = npg_qc::autoqc::qc_store::query->new(id_run => 25);
    my $collection = $store->run_from_db($query);
    if (!$collection->is_empty) {
      # do something
    }

=cut
sub run_from_db {
  my ($self, $query) = @_;
  if (!$query) {
    croak q[Query argument should be defined];
  }
  my $c = npg_qc::autoqc::results::collection->new();
  if (!$self->use_db) {
    if ($self->verbose) {
      carp __PACKAGE__  . q[ object is configured not to use the database];
    }
    return $c;
  }
  foreach my $check_name (@{npg_qc::autoqc::autoqc->checks_list()}) {
    next if ($check_name =~ $NON_STORABLE_CHECK);
    my $dbix_query = { 'id_run' => $query->id_run};
    if (@{$query->positions}) {
      $dbix_query->{'position'} = $query->positions;
    }
    my ($au, $table_class) = npg_qc::autoqc::role::result->class_names($check_name);
    if (!$table_class) {
      croak qq[No DBIx result class name for $check_name];
    }
    my $result_set = $self->qc_schema()->resultset($table_class);
    if ($query->option == $LANES || $query->option == $PLEXES) {
      my $column = 'tag_index';
      my $result_source = $result_set->result_source;
      if (any {$_ eq $column} $result_source->columns()) {
        my $db_default = $result_source->column_info($column)->{'default_value'};
        my $not_default = {q[!=], $db_default};
        $dbix_query->{$column} = ($query->option == $LANES) ? $db_default : $not_default;
      }
    }
    my @rows = $result_set->search($dbix_query)->all();
    $c->add(\@rows);
  }
  return $c;
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

=item Try::Tiny

=item List::MoreUtils

=item npg_qc::autoqc::qc_store::query

=item npg_qc::autoqc::qc_store::options

=item npg_qc::autoqc::results::collection

=item npg_qc::Schema

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt> and Andy Brown E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia and Andy Brown

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

