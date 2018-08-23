package npg_qc::autoqc::db_loader;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use JSON;
use Carp;
use Try::Tiny;
use List::MoreUtils qw/any none/;
use Readonly;

use npg_tracking::util::types;
use npg_qc::Schema;
use npg_qc::autoqc::role::result;
use npg_qc::autoqc::results::collection;
use npg_qc::autoqc::qc_store;
use npg_qc::autoqc::qc_store::query_non_tracking;
use npg_qc::autoqc::qc_store::options qw/$LANES $PLEXES/;

with qw/ npg_tracking::glossary::run
         MooseX::Getopt /;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD             => q[__CLASS__];
Readonly::Scalar my $SEQ_COMPOSITION_PK_NAME => q[id_seq_composition];
Readonly::Scalar my $SLEEP_TIME              => 180;

#############################################################
#              Public attributes and methods                #
#############################################################

has 'archive_path' => (
  is          => 'ro',
  isa         => 'NpgTrackingDirectory',
  required    => 0,
  predicate   => 'has_archive_path',
);

has 'path' => (
  is          => 'ro',
  isa         => 'ArrayRef[NpgTrackingDirectory]',
  required    => 0,
  predicate   => 'has_path',
);

has 'json_file' => (
  is          => 'ro',
  isa         => 'ArrayRef[NpgTrackingReadableFile]',
  required    => 0,
  predicate   => 'has_json_file',
);

has '+id_run' => (
  required    => 0,
);

has 'lane'=> (
  is          => 'ro',
  isa         => 'ArrayRef[NpgTrackingLaneNumber]',
  required    => 0,
  predicate   => 'has_lane',
);

has 'check'   => (
  is          => 'ro',
  isa         => 'ArrayRef[Str]',
  required    => 0,
  predicate   => 'has_check',
);

has 'verbose' => (
  is          => 'ro',
  isa         => 'Bool',
  required    => 0,
  default     => 1,
);

has 'schema' => (
  isa         => 'npg_qc::Schema',
  metaclass   => 'NoGetopt',
  is          => 'ro',
  required    => 0,
  lazy_build  => 1,
);
sub _build_schema {
  return npg_qc::Schema->connect();
}

sub BUILD {
  my $self = shift;

  try {

    ($self->has_archive_path || $self->has_path || $self->has_json_file)
      || croak 'One of archive_path, path or json_file attributes has to be set';

    if ( ($self->has_archive_path && $self->has_path) ||
       ($self->has_archive_path && $self->has_json_file) ||
       ($self->has_path && $self->has_json_file) ) {
      croak 'Only one of archive_path, path or json_file attributes can be set';
    }

    if ($self->has_lane && !$self->has_id_run) {
      croak 'lane attribute cannot be set without setting id_run attribute';
    }

    for my $attr (qw/path json_file check lane/) {
      my $m = 'has_' . $attr;
      if ($self->$m && !@{$self->$attr}) {
        croak "$attr array cannot be empty";
      }
    }

    if ($self->has_check) {
      for my $c (@{$self->check}) {
        if (none { $_ eq $c } @{$self->_checks_list}) {
          croak "Invalid autoqc result class name: $c";
        }
      }
    }
  } catch {
    croak 'Input validation has failed: ' . $_;
  };

  return;
}

sub load{
  my $self = shift;

  my $transaction = sub {
    my $count = 0;
    while (my $obj = $self->_collection->pop) {
      $count += $self->_json2db($obj);
    }
    return $count;
  };

  my $num_loaded = 0;
  try {
    $num_loaded = $self->schema->txn_do($transaction);
  } catch {
    my $m = "Loading aborted, transaction has rolled back: $_";
    $self->_log($m);
    # Retry only if failed to get a lock
    if ($m =~ /Deadlock found when trying to get lock/smxi) {
      $self->_log("Will pause for $SLEEP_TIME seconds, then retry");
      sleep $SLEEP_TIME;
      $num_loaded = $self->schema->txn_do($transaction);
    } else {
      croak $m;
    }
  };
  $self->_log("$num_loaded json files have been loaded");

  return $num_loaded;
}

#############################################################
#             Private attributes and methods                #
#############################################################

has '_schema_sources' => (
  isa         => 'ArrayRef',
  is          => 'ro',
  required    => 0,
  lazy_build  => 1,
);
sub _build__schema_sources {
  my $self = shift;
  return [$self->schema()->sources()];
}
sub _schema_has_source {
  my ($self, $source_name) = @_;
  return any { $_ eq $source_name } @{$self->_schema_sources()};
}

has '_checks_list' => (
  isa        => 'ArrayRef',
  is         => 'ro',
  required   => 1,
  default    => sub {
    return [ @{npg_qc::autoqc::results::collection->new()->checks_list()},
             qw/sequence_summary samtools_stats/ ];
  },
);

has '_collection' => (
  is          => 'ro',
  isa         => 'npg_qc::autoqc::results::collection',
  required    => 0,
  lazy_build  => 1,
);
sub _build__collection {
  my $self = shift;

  my $qc_store = npg_qc::autoqc::qc_store->new(checks_list => $self->_checks_list,
                                               use_db      => 0);
  my $collection;
  my $query;
  my $init_query = {'option'              => $LANES,
                    'id_run'              => $self->id_run,
                    'db_qcresults_lookup' => 0};
  if ($self->has_id_run) {
    if ($self->has_lane) {
      $init_query->{'positions'} = $self->lane;
    }
    $query = npg_qc::autoqc::qc_store::query_non_tracking->new($init_query);
  }

  if ($self->has_archive_path) {
    $collection = $qc_store->load_from_staging_archive($query, $self->archive_path);
    $init_query->{'option'} = $PLEXES;
    $query = npg_qc::autoqc::qc_store::query_non_tracking->new($init_query);
    $collection = $collection->join_collections(
       $collection,
       $qc_store->load_from_staging_archive($query, $self->archive_path));
  } elsif ($self->has_path) {
    $collection = $qc_store->load_from_path(@{$self->path}, $query);
  } elsif ($self->has_json_file) {
    $collection = npg_qc::autoqc::results::collection->new();
    for my $f (@{$self->json_file}) {
      $collection->add($qc_store->json_file2result_object($f));
    }
  } else {
    croak 'Either archive_path or path or json_files attribute should be set.'
  }

  return $collection;
}

sub _json2db{
  my ($self, $obj) = @_;

  my $count = 0;

  try {
    my ($class_name, $dbix_class_name) =
        npg_qc::autoqc::role::result->class_names($obj->class_name);
    if ($dbix_class_name && $self->_schema_has_source($dbix_class_name) &&
        $self->_pass_filter($obj)) {
      my $rs  = $self->schema->resultset($dbix_class_name);
      my $related_composition = $rs->find_or_create_seq_composition($obj->composition());
      if (!$related_composition) {
        croak 'Composition is not found/created';
      }
      $self->_log("Loading $class_name result for " . $obj->composition()->freeze());
      my $values = decode_json($obj->freeze());
      $values->{$SEQ_COMPOSITION_PK_NAME} = $related_composition->$SEQ_COMPOSITION_PK_NAME();
      $self->_values2db($rs, $values);
      $count++;
    }
  } catch {
    my $e = $_;
    $self->_log("Error loading result object: $e");
    croak $e;
  };

  return $count;
}

sub _values2db {
  my ($self, $rs, $values) = @_;

  my $result_class = $rs->result_class;
  $self->_exclude_nondb_attrs($values, $result_class->columns());
  my $row = $rs->find_or_new($values);
  if ($result_class->has_column('iscurrent') && $row->in_storage) {
    $row->update({'iscurrent' => 0});
    $row = $rs->new_result($values);
  }
  # We need to convert non-scalar values (hashes or arrays) to scalars
  $row->set_inflated_columns($values)->insert_or_update();

  return;
}

sub _exclude_nondb_attrs {
  my ($self, $values, @columns) = @_;
  delete $values->{$CLASS_FIELD};
  delete $values->{'composition'};
  foreach my $key ( keys %{$values} ) {
    if (any {$key eq $_} @columns) {
      next;
    }
    delete $values->{$key};
    $self->_log("Not loading field '$key'");
  }
  return;
}

sub _pass_filter {
  my ($self, $obj) = @_;

  my $outcome = 1;

  my $class_name = $obj->class_name;
  if ( $self->has_check && (none {$_ eq $class_name} @{$self->check}) ) {
    $outcome = 0;
  }

  if ( $outcome && $obj->composition->num_components == 1 && $self->has_id_run ) {
    my $component = $obj->composition->get_component(0);
    if ( $component->id_run != $self->id_run ) {
      $outcome = 0;
    } elsif ( $self->has_lane && none {$_ == $component->position} @{$self->lane} ) {
      $outcome = 0;
    } #warn "OUTCOME $outcome for " . $component->position;
  }

  return $outcome;
}

sub _log {
  my ($self, $m) = @_;
  if ($self->verbose) {
    warn "$m\n";
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::autoqc::db_loader

=head1 SYNOPSIS

  my $p = 'npg_qc::autoqc::db_loader';

  # Loading all files
  $p->new(archive_path => '/tmp/mypath')->load();
  $p->new(path => [qw/path1 path2/])->load();
  $p->new(json_file => [qw/file1 file2/])->load();

  # Applying filters
  $p->new(path => [qw/path1 path2/], check => [qw/genotype insert_size/]')->load();
  $p->new(path => [qw/path1 path2/], id_run => 1234, lane => [1,3])->load();

=head1 DESCRIPTION

  Database loader for autoqc results.

  Finds JSON files representing serialised autoqc result objects and loads
  them to a database. JSON files that are not serialized autoqc result objects
  or result objects that do not have database representation are skipped.
  Attributes of result objects which do not have corresponding representation
  in a database are skipped.

  One of archive_path, path and json_files attributes can be used to point
  to the location of JSON files. Only one of these attributes can and should
  be set.

  If filters (check, id_run, lane) are set, they would be applied to load
  only the objects that pass all filters. The id_run and lane filters are not
  applied to autoqc result objects for compositions with multiple components.

=head1 SUBROUTINES/METHODS

=head1 archive_path
 
 The run folder archive directory, an optional attribute.
 The directory should exist. 

=head2 path

  An array of directory paths from where json files have to be loaded.
  Directories should exist. An optional attribute.

=head2 json_files

  An array of json files full paths, an optional attribute.
  Files should exist.

=head2 id_run

  Run id, an optional attribute, acts as a filter.

=head2 lane

  An array of lane numbers to load, an optional attribute, acts as a filter.
  Can only be set if id_run is also set.

=head2 check

  An array of autoqc check names to load, an optional attribute,
  acts as a filter.

=head2 verbose

  A boolean attribute, switches logging on/off, true by default.

=head2 schema

  DBIx connection to the npg_qc database, an optional attribute,
  will be built automatically if not set.

=head2 load

  A method. Finds JSON files representing autoqc result objects
  loads them to a database. Returns the number of loaded files.

=head2 BUILD

  Method run by Moose before returning a new object instance to the
  caller. Performs consistency checks for object's attribute values.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item MooseX::Getopt

=item Carp

=item Try::Tiny

=item List::MoreUtils

=item Readonly

=item npg_qc::Schema

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

=cut
