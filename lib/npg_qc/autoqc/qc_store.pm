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
use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES $MULTI/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::role::result;
use npg_qc::autoqc::results::collection;

our $VERSION = '0';

Readonly::Scalar my $CLASS_FIELD => q[__CLASS__];

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

has 'use_db'       => ( isa        => 'Bool',
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

has '_checks_list' => ( isa        => 'ArrayRef',
                        is         => 'ro',
                        required   => 1,
                        default    => sub {
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
  if (!defined $query) { croak q[Query object should be defined]; }
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

Data for a number of lanes returned as an npg_qc::autoqc::results::collection object.
The second argument is a reference to a hash defining the lanes. Run IDs should be
used as keys. A reference to an array with lane numbers should be used as values.

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

De-serializes objects from JSON files found in the directories given by the argument
list of paths. If a query object is defined, selects objects corresponding to a run
defined by the query object's id_run attribute. Path string can have glob expansion
characters as per Perl glob function documentation.

Errors if a list of paths is undefined or empty.

Returns a collection object (npg_qc::autoqc::results::collection) containing autoqc
result objects corresponding to JSON files.

Can only deal with classes from the npg_qc::autoqc::results name space. Each class
should inherit from the npg_qc::autoqc::results::result object. Errors if
de-seriaization fails either because JSON is invalid or cannot be de-serialized.

Does not load twice from the same path. Lanes selection is not performed even if
defined in the query object,

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
  my @patterns = map { join q[/], $_ , $pattern . q[*.json] } uniq @paths;
  my $c = npg_qc::autoqc::results::collection->new();

  foreach my $file (glob(join q[ ], @patterns)) {
    my $r = $self->_json2result($file);
    if ($r) {
      $c->add($r);
    }
  }

  return $c;
}

=head2 load_from_staging

De-serializes objects from JSON files found in staging area. Finds
runfolders on staging using id_run attribute of the query object. Errors if
de-seriaization fails either because JSON is invalid or cannot be de-serialized.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files.  Returns an empty
collection if run is not on staging or the run folder path was not found.

 my $query = npg_qc::autoqc::qc_store::query->new(id_run => 123);
 my $c     = $obj->load_from_staging($query);

=cut

sub load_from_staging { ##no critic (Subroutines::ProhibitExcessComplexity)
  my ($self, $query) = @_;

  defined $query or croak q[Query object should be defined];

  my $rfs;
  my $e;
  try {
    $rfs = npg_tracking::illumina::runfolder->new(
      id_run              => $query->id_run,
      npg_tracking_schema => $query->npg_tracking_schema
    );
    $rfs->analysis_path; # Might fail to find the run folder analysis directory.
  } catch {
    $e = $_;
  };

  my $collection;

  if ($e) {
    carp sprintf 'Failed to load data from staging for query "%s" : "%s"',
         $query->to_string, $e;
  } else {

    my $old_style = -e $rfs->qc_path;
    my %lh = map { $_ => 1 } @{$query->positions};
    my @per_lane_dirs = @{$query->positions}
                        ? map { $rfs->lane_qc_path($_) } @{$query->positions}
                        : @{$rfs->lane_qc_paths};

    my @dirs = ();
    #####
    # QC results for merged entities, plex-level merge only for now
    #
    if ( $query->option == $MULTI ) {
      push @dirs, join q[/], $rfs->archival_path, '*plex*', 'qc';
    }

    #####
    # Lane-level QC results
    #
    if ( $query->option == $LANES || $query->option == $ALL ) {
      push @dirs, $old_style ? ($rfs->qc_path) : @per_lane_dirs;
    }

    #####
    # Plex-level QC results for unmerged entities
    #
    if ( $query->option == $PLEXES || $query->option == $ALL ) {
      if ($old_style) {
        push @dirs, @per_lane_dirs;
      } else {
        push @dirs, map {"$_/../plex*/qc"} @per_lane_dirs;
      }
    }

    if (@dirs) {
      $collection = $self->load_from_path(@dirs, $query);
    }

    #####
    # Filter results by position
    # 
    if (@{$query->positions} && $old_style && $collection->size &&
        ($query->option == $LANES || $query->option == $ALL)) {
      my @in = grep { $_->composition->num_components > 1 || $lh{$_->position} }
               @{$collection->results};
      $collection = npg_qc::autoqc::results::collection->new();
      $collection->add(\@in);
    }
  }

  $collection ||= npg_qc::autoqc::results::collection->new();

  return $collection;
}

=head2 load_from_db

Loads auto QC results object from the database using  query parameters defined
by the query object.

Returns a collection object (npg_qc::autoqc::results::collection) containing
autoqc result objects corresponding to JSON files.  Returns an empty
collection if no results are found.

 my $query = npg_qc::autoqc::qc_store::query->new(id_run => 123);
 my $c     = $obj->load_from_db($query);

=cut

sub load_from_db {
  my ($self, $query) = @_;

  if (!$query) {
    croak q[Query argument should be defined];
  }

  my $c = npg_qc::autoqc::results::collection->new();

  if ($self->use_db) {
    my $ti_key = 'tag_index';
    foreach my $check_name (@{$self->_checks_list()}) {
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

      my $rs = $self->qc_schema()->resultset($table_class);
      my $composition_size = 1; # simple cases only for now
      $c->add([$rs->search_autoqc($dbix_query, $composition_size)->all()]);
    }
  } else {
    carp __PACKAGE__  . q[ object is configured not to use the database];
  }

  return $c;
}

sub _query_obj {
  my ($self, $id_run, $lanes, $what, $db_lookup, $npg_schema) = @_;

  my $obj_hash = { id_run => $id_run, npg_tracking_schema => $npg_schema };
  if ($lanes) { $obj_hash->{'positions'} = $lanes; }
  if ($what) { $obj_hash->{'option'} = $what; }
  if (defined $db_lookup) { $obj_hash->{'db_qcresults_lookup'} = $db_lookup; }
  return npg_qc::autoqc::qc_store::query->new($obj_hash);
}

sub _json2result {
  my ($self, $file) = @_;

  my $result;
  try {
    my $json_string = slurp($file);
    my $json = decode_json($json_string);
    my $class_name = delete $json->{$CLASS_FIELD};
    if ($class_name) {
      ($class_name, my $dbix_class_name) =
          npg_qc::autoqc::role::result->class_names($class_name);
    }
    if ($class_name && any {$_ eq $class_name} @{$self->_checks_list()}) {
      my $module = $npg_qc::autoqc::results::collection::RESULTS_NAMESPACE . q[::] . $class_name;
      load_class($module);
      $result = $module->thaw($json_string);
    }
  } catch {
    croak "Failed reading $file: $_";
  };

  return $result;
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

