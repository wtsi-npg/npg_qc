package npg_qc::autoqc::qc_store;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Carp;
use List::MoreUtils qw/any uniq/;
use Readonly;
use Perl6::Slurp;
use JSON;
use Class::Load qw/load_class/;

use npg_tracking::illumina::runfolder;
use npg_qc::Schema;
use npg_qc::autoqc::qc_store::options qw/$ALL $ALLALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::role::result;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD       => q[__CLASS__];
Readonly::Scalar my $QC_DIR_NAME       => q[qc];

## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitManyArgs)

=head1 NAME

npg_qc::autoqc::qc_store

=head1 SYNOPSIS

=head1 DESCRIPTION

Transparent retrieval of stored auto QC data.
One instance of this class should be created by the application.

=head1 SUBROUTINES/METHODS

=head2 use_db

A boolean flag. If it is false, data will be retrieved from
the staging area only; no attempt to connect to the QC database
will be made. True by default.

=cut

has 'use_db' => (
  isa        => 'Bool',
  is         => 'ro',
  required   => 0,
  default    => 1,
);

=head2 qc_schema

DBIx schema connection

=cut

has 'qc_schema' => (
  isa        => 'Maybe[npg_qc::Schema]',
  is         => 'ro',
  required   => 0,
  predicate  => 'has_qc_schema',
  lazy_build => 1,
);
sub _build_qc_schema {
  my $self = shift;
  if ($self->use_db) {
    return npg_qc::Schema->connect();
  }
  return;
}

=head2 checks_list

=cut

has 'checks_list' => (
  isa      => 'ArrayRef',
  is       => 'ro',
  required => 1,
  default  => sub {
    return npg_qc::autoqc::results::collection->new()->checks_list();
  },
);

=head2 BUILD

=cut

sub BUILD {
  my $self = shift;
  if ($self->use_db && $self->has_qc_schema && (!defined $self->qc_schema)) {
    croak 'Incompatible attribute values: ' .
          'qc_schema attribute is explicitly undefined, use_db is true';
  }
  return;
}

=head2 load

Data for a query returned as an npg_qc::autoqc::results::collection object.

=cut

sub load {
  my ($self, $query) = @_;
  defined $query or croak q[Query object should be defined];
  my $collection;
  if ($self->use_db && $query->db_qcresults_lookup) {
    $collection = $self->load_from_db($query);
  }
  if (!defined $collection || $collection->is_empty()) {
    $collection = $self->load_from_staging($query);
  }
  return $collection;
}

=head2 load_lanes

Data for a number of lanes returned as an npg_qc::autoqc::results::collection
object. The second argument is a reference to a hash defining the lanes. Run
IDs should be used as keys. A reference to an array with lane numbers should
be used as values.

If npg_schema argument is undefined, stored globs will not be used.

=cut

sub load_lanes {
  my ($self, $run_lanes_hash, $db_lookup, $what, $npg_schema) = @_;

  my @collections = ();
  foreach my $id_run (keys %{$run_lanes_hash}) {
    my $query = $self->_query_obj($id_run, $run_lanes_hash->{$id_run},
                                  $what, $db_lookup, $npg_schema);
    push @collections, $self->load($query, $npg_schema);
  }
  return npg_qc::autoqc::results::collection->join_collections(@collections);
}

=head2 load_from_path

De-serializes objects from JSON files found in the directories given by the
argument list of paths. If a query object is defined, selects objects
corresponding to a run defined by the query object's id_run attribute. Path
string can have glob expansion characters as per Perl glob function
documentation.

Errors if a list of paths is undefined or empty.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files.

Can only deal with classes from the npg_qc::autoqc::results name space. Each
class should inherit from the npg_qc::autoqc::results::result object. Errors
if de-seriaization fails either because JSON is invalid or cannot be
de-serialized.

Does not load twice from the same path. Lanes selection is not performed even
if defined in the query object,

 my $c = $obj->load_from_path(@paths);
 my $c = $obj->load_from_path(@paths, $query_obj);

=cut

sub load_from_path {
  my ($self, @paths) = @_;

  my $query;
  if (@paths) {
    $query = pop @paths;
    if (ref $query ne 'npg_qc::autoqc::qc_store::query') {
      push @paths, $query;
      undef $query;
    }
  }

  if (!@paths) {
    croak 'A list of at least one path is required';
  }

  my $pattern = $query ? $query->id_run : q[];
  $pattern .= q[*.json];
  my @patterns = map { join q[/], $_ , $pattern }
                 uniq
                 grep { defined }
                 @paths;
  my $c = npg_qc::autoqc::results::collection->new();

  foreach my $file (glob(join q[ ], @patterns)) {
    $c->add($self->json_file2result_object($file));
  }

  return $c;
}

=head2 load_from_staging

De-serializes objects from JSON files found in staging area. Finds
runfolders on staging using id_run attribute of the query object.
The query object should be of npg_qc::autoqc::qc_store::query type.

Errors if de-seriaization fails either because JSON is invalid or
cannot be de-serialized.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files.  Returns an empty
collection if run is not on staging or the run folder path was not found.

 my $query = npg_qc::autoqc::qc_store::query->new(
             id_run => 123,
             npg_tracking_schema => npg_tracking::Schema->connect());
 my $c     = $obj->load_from_staging($query);

=cut

sub load_from_staging {
  my ($self, $query) = @_;

  defined $query or croak q[Query object should be defined];
  my $expected_type = q[npg_qc::autoqc::qc_store::query];
  (ref $query eq $expected_type)
    or croak qq[Query object should be of type $expected_type];

  my $archive_path;
  try {
    $archive_path = npg_tracking::illumina::runfolder->new(
      id_run              => $query->id_run,
      npg_tracking_schema => $query->npg_tracking_schema
    )->archive_path;
  } catch {
    carp sprintf 'Failed to load data from staging for query "%s" : "%s"',
      $query->to_string, $_;
  };

  #####
  # Potential error retrieving data from the archive directory is
  # not captured; this is deliberate.
  #
  return $archive_path ?
    $self->load_from_staging_archive($query, $archive_path) :
    npg_qc::autoqc::results::collection->new();
}

=head2 load_from_staging_archive

De-serializes objects from JSON files found in the given archive directory.
The query object can be either of npg_qc::autoqc::qc_store::query
or npg_qc::autoqc::qc_store::query_non_tracking type.

Errors if de-seriaization fails either because JSON is invalid or
cannot be de-serialized.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files.

 my $query = npg_qc::autoqc::qc_store::query_non_tracking->new(
             id_run => 123);
 my $c     = $obj->load_from_staging_archive($query, $archive_dir); 

=cut

sub load_from_staging_archive {
  my ($self, $query, $archive_path) = @_;

  defined $query or croak q[Query object should be defined];
  (defined $archive_path && -d $archive_path)
    or croak q[Archive directory should be defined and should exist];

  my @plex_globs = map { 'lane' . $_ } @{$query->positions};
  my @lane_globs = @plex_globs ? @plex_globs : 'lane*';
  push @plex_globs, @plex_globs ? 'lane*-*' : 'lane*';
  push @plex_globs, q[];
  @plex_globs = map { $_ . '/plex*'} @plex_globs;
  @plex_globs = map { "$archive_path/$_/$QC_DIR_NAME"} @plex_globs;
  @lane_globs = map { "$archive_path/$_/$QC_DIR_NAME"} @lane_globs;

  my @results = ();
  my $merged  = 0;

  #####
  # Plex-level QC results for either merged or unmerged entities.
  #
  if ( $query->option == $PLEXES ||
       $query->option == $ALL || $query->option == $ALLALL) {
    my $collection = $self->load_from_path(@plex_globs, $query);
    $merged = any {$_->composition->num_components > 1} @{$collection->results};
    @results = @{$collection->results};
  }

  #####
  # Lane-level QC results. Do not add lanes for $ALL option if results
  # for merged entities are present - it would be wrong to display two
  # types of results together.
  #
  # We should deal with lane-level merges here - TODO.
  #
  if ( $query->option == $LANES || $query->option == $ALLALL ||
      ($query->option == $ALL && !$merged) ) {
    my $collection = $self->load_from_path(@lane_globs, $query);
    push @results, @{$collection->results};
  }

  #####
  # Filter results by position.
  #
  if (@{$query->positions} && @results) {
    my %lh = map { $_ => 1 } @{$query->positions};
    @results = grep { any { exists $lh{$_->position} } $_->composition->components_list }
               @results;
  }

  my $collection = npg_qc::autoqc::results::collection->new();
  $collection->add(\@results);

  return $collection;
}

=head2 load_from_db

Loads auto QC results object from the database using  query parameters defined
by the query object.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result corresponding to the argument compositions. Only results for classes
listed in the checks_list attribute are returned. Returns an empty collection
if no results are found or if this object is configured not to use the database.

Does not return results that only partially belong to the requested run, ie
are for merged entities where some components belong to a different run. This
rule does not apply to positions.

 my $query = npg_qc::autoqc::qc_store::query->new(id_run => 123);
 my $c     = $obj->load_from_db($query);

=cut

sub load_from_db {
  my ($self, $query) = @_;

  $query or croak q[Query object should be defined];

  my @rows = ();

  if ($self->use_db) {
    my $prefix = q[seq_component.];
    my $dbix_query = { $prefix.'id_run' => $query->id_run};
    if (@{$query->positions}) {
      $dbix_query->{$prefix.'position'} = $query->positions;
    }
    if ($query->option == $LANES) {
      $dbix_query->{$prefix.'tag_index'} = undef;
    } elsif ($query->option == $PLEXES) {
      $dbix_query->{$prefix.'tag_index'} = {q[!=], undef};
    }

    my $rs = $self->qc_schema()->resultset('SeqComposition')->search(
      $dbix_query,
      {prefetch => {'seq_component_compositions' => 'seq_component'}}
    );

    my $mc_compositions_flag = 0;
    my @lane_rows = ();

    while (my $row = $rs->next()) {

      my $rs_linking_rows  = $row->seq_component_compositions;
      my $num_linking_rows = $rs_linking_rows->count();
      my $linking_row      = $rs_linking_rows->next;
      my $composition_size = $linking_row->size();

      # Examine compositions where not all components were returned
      # by the query. Can happen if some components come from
      # other runs - we need to exclude such cases, while leaving
      # data with other reasons for a mismatch in.
      if ($num_linking_rows != $composition_size) {
        # Unfortunately, to examine all components of the composition,
        # we have to run a new query.
        $self->qc_schema()->resultset('SeqComponentComposition')->search(
          {
           'id_seq_composition'   => $row->id_seq_composition,
           'seq_component.id_run' => {q[!=], $query->id_run}
          },
          {prefetch => 'seq_component'}
        )->count && next;
      }

      # Are any results for the multi-component composition?
      # If so, update the flag.
      ($composition_size > 1) and $mc_compositions_flag++;

      # Keep lane-level results separately for now.
      if (defined $linking_row->seq_component->tag_index()) {
        push @rows, $row;
      } else {
        push @lane_rows, $row;
      }
    }

    # Re-unite lane results with the rest, unless, for the purpose
    # of SeqQC display, we want to supress their return.
    if (@lane_rows && !(($query->option == $ALL) && $mc_compositions_flag)) {
      push @rows, @lane_rows;
    }

  } else {
    carp __PACKAGE__  . q[ object is configured not to use the database];
  }

  return $self->_db_collection4compositions([map { $_->id_seq_composition } @rows]);
}

=head2 load_from_db_via_composition

Similar to load_from_db, but loads database results for an array of composition
objects.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result corresponding to the argument compositions. Only results for classes
listed in the checks_list attribute are returned. Returns an empty collection
if no results are found or if this object is configured not to use the database.

If the argument composition array is empty, an empty collection is returned.

 # Assuming $c1 and $c2 are objects of type npg_tracking::glosary::composition
 my $c = $obj->load_from_db_via_composition([$c1, $c2]);

=cut

sub load_from_db_via_composition {
  my ($self, $compositions) = @_;

  $compositions or croak
    'Array of composition objects should be given';

  my @rows = ();
  if ($self->use_db && @{$compositions}) {
    @rows = $self->qc_schema()->resultset('SeqComposition')->search(
      {'me.digest' => [map { $_->digest } @{$compositions}]}
    );
  }

  return $self->_db_collection4compositions([map { $_->id_seq_composition } @rows]);
}

=head2 json_file2result_object

Reads an argument JSON file and converts the content into in-memory autoqc
result object of a class specified by the __CLASS__ field. Sets the value
of the result_file_path attrubute of the result object to the argument
file path.

Returns an autoqc result object or an undefined value if the JSON
string does not contain the __CLASS__ field or this class is not
recognised as autoqc result class.

Errors if the file cannot be read or de-serialization fails.

=cut

sub json_file2result_object {
  my ($self, $file_path) = @_;

  my $result;
  try {
    my $json_string = slurp($file_path);
    my $json = decode_json($json_string);
    my $class_name = delete $json->{$CLASS_FIELD};
    if ($class_name) {
      ($class_name, my $dbix_class_name) =
          npg_qc::autoqc::role::result->class_names($class_name);
    }
    if ($class_name && any {$_ eq $class_name} @{$self->checks_list()}) {
      my $module = join q[::],
                   $npg_qc::autoqc::results::collection::RESULTS_NAMESPACE,
                   $class_name;
      load_class($module);
      $result = $module->thaw($json_string);
      $result->result_file_path($file_path);
    }
  } catch {
    croak "Failed converting $file_path to autoqc result object: $_";
  };

  return $result;
}

########################################################################
############# Private attributes and methods ###########################
########################################################################

has '_available_classes' => (
  isa        => 'ArrayRef',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__available_classes {
  my $self = shift;

  my @names = ();
  foreach my $check_name (@{$self->checks_list()}) {
    my ($au, $table_class) = npg_qc::autoqc::role::result->class_names($check_name);
    $table_class or croak qq[No DBIx result class name for $check_name];
    try {
      my $rs = $self->qc_schema()->resultset($table_class);
      # Still here? - DBIx result class exists.
      push @names, $table_class;
    };
  }
  return \@names;
}

sub _db_collection4compositions {
  my ($self, $composition_ids) = @_;

  $composition_ids or croak
    'An array of seq_composition table primary keys is required';

  my @rows = ();
  if (@{$composition_ids}) {
    foreach my $name (@{$self->_available_classes}) {
      push @rows, $self->qc_schema()->resultset($name)
        ->search({'me.id_seq_composition' => $composition_ids})->all();
    }
  }

  return npg_qc::autoqc::results::collection->new(results => \@rows);
}

sub _query_obj {
  my ($self, $id_run, $lanes, $what, $db_lookup, $npg_schema) = @_;

  my $obj_hash = { id_run => $id_run, npg_tracking_schema => $npg_schema };
  if ($lanes) { $obj_hash->{'positions'} = $lanes; }
  if ($what) { $obj_hash->{'option'} = $what; }
  if (defined $db_lookup) { $obj_hash->{'db_qcresults_lookup'} = $db_lookup; }
  return npg_qc::autoqc::qc_store::query->new($obj_hash);
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

=item Readonly

=item Perl6::Slurp

=item JSON

=item Class::Load

=item npg_tracking::illumina::runfolder

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=item Andy Brown E<lt>ajb@sanger.ac.ukE<gt>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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

