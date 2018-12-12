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
use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::role::result;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD       => q[__CLASS__];
Readonly::Scalar my $NO_TAG_INDEX      => -1;
Readonly::Scalar my $QC_DIR_NAME       => q[qc];
Readonly::Hash   my %READ_NAME_MAPPING => ( forward => 1,
                                            reverse => 2,
                                            index   => 't', );

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
    my $r = $self->json_file2result_object($file);
    if ($r) {
      $c->add($r);
    }
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

  my $rfo = $self->_runfolder_obj($query);

  return $rfo ? $self->load_from_staging_archive($query, $rfo->archive_path)
              : npg_qc::autoqc::results::collection->new();
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

sub load_from_staging_archive { ##no critic (Subroutines::ProhibitExcessComplexity)
  my ($self, $query, $archive_path) = @_;

  defined $query or croak q[Query object should be defined];
  (defined $archive_path && -d $archive_path)
    or croak q[Archive directory should be defined and should exist];

  my %lh           = map { $_ => 1 } @{$query->positions};
  my @lane_dirs    = glob $self->_lane_dirs_glob($archive_path, $query);
  my @lane_qc_dirs = map { join q[/], $_, $QC_DIR_NAME } @lane_dirs;
  my $old_qc_dir   = join q[/], $archive_path, $QC_DIR_NAME;
  my $old_style    = -d $old_qc_dir;

  my @collections = ();
  my @dirs        = ();
  my $merged      = 0;

  #####
  # Plex-level QC results for either merged or unmerged entities,
  # but not both.
  #
  if ( $query->option == $PLEXES || $query->option == $ALL ) {
    my $collection;
    if ($old_style) {
      push @dirs, @lane_qc_dirs;
    } else {
      if (@lane_dirs) {
        my @tdirs = map {"$_/*plex*/$QC_DIR_NAME"} @lane_dirs;
        $collection = $self->load_from_path(@tdirs, $query);
      }
      # No results for one component compositions - try merges
      if (!$collection || $collection->is_empty) {
        my @tdirs;
        push @tdirs, join q[/], $archive_path, 'plex*', $QC_DIR_NAME;
        push @tdirs, join q[/], $archive_path, 'lane*-', 'plex*', $QC_DIR_NAME;
        $collection = $self->load_from_path(@tdirs, $query);
        if ($collection->size) {
          $merged = 1;
        }
      }
      if ($collection->size) {
        push @collections, $collection;
      }
    }
  }

  #####
  # Lane-level QC results. Do not add lanes for $ALL option if results
  # for merged entities are present - it would be wrong to display two
  # types of results together.
  #
  # We should deal with lane-level merges here - TODO.
  #
  if ( $query->option == $LANES || ($query->option == $ALL && !$merged) ) {
    push @dirs, $old_style ? $old_qc_dir : @lane_qc_dirs;
  }

  if (@dirs) {
    push @collections, $self->load_from_path(@dirs, $query);
  }
  my $collection = npg_qc::autoqc::results::collection->join_collections(@collections);

  #####
  # Filter results for one-component compositions by position.
  # 
  if (@{$query->positions} && $old_style && $collection->size &&
       ($query->option == $LANES || $query->option == $ALL)) {
    my @in = grep { $_->num_components > 1 || $lh{$_->position} }
             @{$collection->results};
    $collection = npg_qc::autoqc::results::collection->new();
    $collection->add(\@in);
  }

  return $collection;
}

=head2 load_from_db

Loads auto QC results object from the database using  query parameters defined
by the query object.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files. Returns an empty
collection if no results are found.

 my $query = npg_qc::autoqc::qc_store::query->new(id_run => 123);
 my $c     = $obj->load_from_db($query);

=cut

sub load_from_db {
  my ($self, $query) = @_;

  $query or croak q[Query object should be defined];

  my @results = ();

  if ($self->use_db) {
    my $ti_key = 'tag_index';
    foreach my $check_name (@{$self->checks_list()}) {
      my $dbix_query = { 'id_run' => $query->id_run};
      if (@{$query->positions}) {
        $dbix_query->{'position'} = $query->positions;
      }
      my ($au, $table_class) = npg_qc::autoqc::role::result->class_names($check_name);
      if (!$table_class) {
        croak qq[No DBIx result class name for $check_name];
      }
      if ($query->option == $LANES) {
        $dbix_query->{$ti_key} = undef;
      } elsif ($query->option == $PLEXES) {
        $dbix_query->{$ti_key} = {q[!=], undef};
      }

      my @check_results = $self->qc_schema()->resultset($table_class)
                         ->search_autoqc($dbix_query)->all();
      push @results, @check_results;
    }
  } else {
    carp __PACKAGE__  . q[ object is configured not to use the database];
  }

  if ( @results
       && ($query->option == $ALL)
       && (any { $_->num_components > 1 } @results) ) {
    @results = grep { ($_->num_components != 1) ||
                       defined $_->composition->get_component(0)->tag_index }
               @results;
  }

  my $c = npg_qc::autoqc::results::collection->new();
  $c->add(\@results);

  return $c;
}

=head2 load_fastqcheck_content

Returns fastqcheck file content as a string for a lane entity defined
by the argument query object. Takes an optional second argument, read name,
which defaults to a forward read. Valid values for the read name are
'forward, 'reverse and 'index'.

Returns an undefined value if the content is not found either in the
database or on staging.

  my $content = $obj->load_fastqcheck_content($query);
  my $content = $obj->load_fastqcheck_content($query, 'reverse');

=cut

sub load_fastqcheck_content {
  my ($self, $query, $read) = @_;

  defined $query or croak 'Query object i srequired';
  if ($query->option != $LANES) {
    croak q[Fastqcheck file content can be loaded for lanes only];
  }
  if (scalar @{$query->positions} != 1) {
    croak q[Fastqcheck file content can be loaded for one lane only];
  }

  $read ||= 'forward';
  if (!exists $READ_NAME_MAPPING{$read}) {
    croak qq[Unknow read value $read];
  }

  my $content;
  if ($self->use_db && $query->db_qcresults_lookup) {
    $content = $self->_fqchck_load_from_db($query, $read);
  }
  if (!$content) {
    $content = $self->_fqchck_load_from_staging($query, $read);
  }

  return $content;
}

=head2 load_fastqcheck_content_from_path

Returns fastqcheck file content as a string  for a lane entity defined
by the argument query object. Looks for fastqcheck files in the directories
specified by the second argument. Takes an optional third argument,
read name, see details in the documentation for load_fastqcheck_content
method.

Returns an undefined value if the file for the entiry is not found.

  my @paths = qw/path1 path2/;
  my $content = $obj->load_fastqcheck_content_from_path($query, \@paths);
  my $content = $obj->load_fastqcheck_content_from_path($query, \@paths,
                                                        'reverse');

=cut

sub load_fastqcheck_content_from_path {
  my ($self, $query, $paths, $read) = @_;

  defined $query or croak q[Query object needed];
  ($paths and @{$paths}) or croak q[Path needed];
  $read ||= 'forward';
  if (!exists $READ_NAME_MAPPING{$read}) {
    croak qq[Unknow read value $read];
  }

  my $position = $query->positions->[0];
  my @files = ();
  foreach my $path (@{$paths}) {
    my $file = join q[/], $path, sprintf '%i_%i_%s.fastqcheck',
                                        $query->id_run,
                                        $position,
                                        $READ_NAME_MAPPING{$read};
    if (-f $file) {
      push @files, $file;
    } elsif ($read eq 'forward') {
      $file = join q[/], $path, sprintf '%i_%i.fastqcheck',
                                        $query->id_run,
                                        $position;
      if (-f $file) {
        push @files, $file;
      }
    }
  }

  my $content;
  if (scalar @files > 1) {
    carp q[Too many fastqcheck files match the query];
  } else {
    if (@files) {
      $content = slurp $files[0];
    }
  }

  return $content;
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

sub _fqchck_load_from_db {
  my ($self, $query, $read) = @_;
  my $where = {split => 'none', tag_index => $NO_TAG_INDEX};
  $where->{'id_run'}   = $query->id_run;
  $where->{'position'} = $query->positions->[0];
  $where->{'section'}  = $read;
  my $row = $self->qc_schema()->resultset('Fastqcheck')->search($where)->next();
  if ($row) {
    return $row->file_content;
  }
  return;
}

sub _fqchck_load_from_staging {
  my ($self, $query, $read) = @_;
  my $rfs = $self->_runfolder_obj($query);
  my $content;
  if ($rfs) {
    my $position = $query->positions->[0];
    my $location = _is_old_style_rf($rfs)
                   ? $rfs->archive_path
                   : join q[/], $rfs->archive_path, 'lane'.$position;
    $content = $self->load_fastqcheck_content_from_path($query, [$location], $read);
  }
  return $content;
}

sub _runfolder_obj {
  my ($self, $query) = @_;

  my $rfs;
  try {
    $rfs = npg_tracking::illumina::runfolder->new(
      id_run              => $query->id_run,
      npg_tracking_schema => $query->npg_tracking_schema
    );
    $rfs->analysis_path; # Might fail to find the run folder analysis directory.
  } catch {
    undef $rfs;
    carp sprintf 'Failed to load data from staging for query "%s" : "%s"',
      $query->to_string, $_;
  };

  return $rfs;
}

sub _is_old_style_rf {
  my $rf_obj = shift;
  return -e $rf_obj->qc_path;
}

sub _lane_dirs_glob {
  my ($self, $archive_path, $query) = @_;
  my $glob = join q[/], $archive_path, 'lane';
  if ($query && @{$query->positions}) {
    my $p_string = join q[,], @{$query->positions};
    $glob .= qq[{$p_string}];
  } else {
    $glob .= q[*];
  }
  return $glob;
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

Copyright (C) 2018 GRL

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

