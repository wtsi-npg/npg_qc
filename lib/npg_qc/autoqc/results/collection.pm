#########
# Author:        Marina Gourtovaia
# Created:       03 September 2009
#

package npg_qc::autoqc::results::collection;

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use MooseX::AttributeHelpers;
use Carp;
use English qw(-no_match_vars);
use List::MoreUtils qw(any none);
use Module::Pluggable::Object;
use Readonly;
use File::Basename;
use Moose::Meta::Class;

use npg_qc::autoqc::autoqc;
use npg_tracking::illumina::run::short_info;
use npg_tracking::illumina::run::folder;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::role::rpt_key;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitUnusedPrivateSubroutines)

=head1 NAME

npg_qc::autoqc::results::collection

=head1 SYNOPSIS

 my $collection = npg_qc::autoqc::results::collection->new();
 my $r = npg_qc::autoqc::results::insert_size->new(id_run => 222, path => q[mypath], position => 1);
 $collection->is_empty(); # returns true
 $collection->add($r);
 $collection->size(); #returns 1
 $collection->sort();
 my $slice_collection = $collection->slice(q[position], 3);
 my $search_result_collection = $collection->search({position => 1});

=head1 DESCRIPTION

 A wrapper around a list of objects, which are derived from the npg_qc::autoqc::results::result object.
 Has methods for sorting, slicing and searching the collection.

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar  my $RESULTS_NAMESPACE    => q[npg_qc::autoqc::results];
Readonly::Scalar  my $LESS    => -1;
Readonly::Scalar  my $MORE    =>  1;
Readonly::Scalar  my $EQUAL   =>  0;

=head2 results

A reference to a list of currently stored objects.

=cut
has 'results' => (
      metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[Object]',
      default   => sub { [] },
      provides  => {
          'push' => 'push',
          'pop'  => 'pop',
          'count'  => 'size',
          'empty'  => 'empty',
          'clear'  => 'clear',
          'sort_in_place' => 'sort_in_place',
          'first'  => 'first',
          'last'   => 'last',
          'delete' => 'delete',
          'get'    => 'get',
          'elements'    => 'all',
      },
                 );


=head2 _result_classes

A reference to a list of result classes. While making a list, the build method
requires each of the class modules.

=cut
has '_result_classes' => ( isa         => 'ArrayRef',
                           is          => 'ro',
                           required    => 0,
                           lazy_build  => 1,
                         );


sub _build__result_classes {
    my $self = shift;

    my @classes = Module::Pluggable::Object->new(
        require     => 1,
        search_path => $RESULTS_NAMESPACE,
        except      => [$RESULTS_NAMESPACE . q[::result],
                        $RESULTS_NAMESPACE . q[::collection]],
    )->plugins;
    my @class_names = ();
    foreach my $class (@classes) {
        my ($class_name) = $class =~ /(\w+)$/smx;
        push @class_names, $class_name;
    }
    return \@class_names;
}


=head2 add

Adds objects to the collection. The argument should be either one object or a reference
to an array. If the latter, all objects in the array will be added to the collection
one by one .

 my $collection = npg_qc::autoqc::results::collection->new();
 my $r = npg_qc::autoqc::results::insert_size->new(id_run => 222, path => q[mypath], position => 1);
 $collection->add($r);

=cut
sub add {
    my ($self, $r) = @_;
    if(ref $r eq q{ARRAY}) {
        foreach my $el (@{$r}) {
            $self->push($el);
        }
    } else {
        $self->push($r);
    }
    return 1;
}


=head2 add_from_dir

De-serializes objects from JSON files found in the directory given by the argument.
Adds these de-serialized objects to this collection.
Can only deal with classes from the npg_qc::autoqc::results name space. Each class
should inherit from the npg_qc::autoqc::results::result object.

 my $c = npg_qc::autoqc::results::collection->new();
 my $path = catfile(cwd, q[t/data/autoqc/rendered/json_paired_run]);
 $c->add_from_dir($path);

=cut
sub add_from_dir {
    my ($self, $path, $lanes, $id_run) = @_;

    my $pattern = $id_run ? $id_run : q[];
    $pattern = $path . q[/] . $pattern . q[*.json];
    my @files = glob $pattern;
    my @classes = @{$self->_result_classes};

    ## no critic (ProhibitBooleanGrep)

    foreach my $file (@files) {
        my ($filename, $dir, $extension) = fileparse($file);
        my $loaded = 0;
        foreach my $class (@classes) {
            if ($filename =~ /$class/smx) {
                my $module = $RESULTS_NAMESPACE . q[::] . $class;
                my $result = $module->load($file);
                my $position = $result->position;
                if (!defined $lanes || !@{$lanes} || grep {/^$position$/smx} @{$lanes} ) {
                    $self->add($result);
                }
                $loaded = 1;
                last;
            }
        }
        if (!$loaded) {
            carp qq[Cannot identify class for $file];
        }
    }

    return 1;
}

=head2 add_from_staging

De-serializes objects from JSON files found in staging area.
Adds these de-serialized objects to this collection.
Also see add_from_dir method.

 use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
 use npg_qc::autoqc::results::collection;

 my $id_run = 1234;
 my $c = npg_qc::autoqc::results::collection->new();

 $c->add_from_staging($id_run); #retrieve main results for a run for all lanes
 $c->add_from_staging($id_run, []); #retrieve main results for a run for all lanes
 $c->add_from_staging($id_run, [], $LANES); #retrieve main results for a run for all lanes
 $c->add_from_staging($id_run, [1,2]); #retrieve main results for lanes 1 and 2
 $c->add_from_staging($id_run, [1,2], $LANES) #retrieve main results for lanes 1 and 2
 $c->add_from_staging($id_run, [], $PLEXES); #retrieve only results for plexes for all available lanes
 $c->add_from_staging($id_run, undef, $ALL); #retrieve both main results and results for plexes for all available lanes
 $c->add_from_staging($id_run, [1,2], $PLEXES); #retrieve results for plexes for lanes 1 and 2
 $c->add_from_staging($id_run, [1,2], $ALL); #retrieve both main and plex results for lanes 1 and 2

=cut
sub add_from_staging {
    my ($self, $id_run, $lanes, $what) = @_;

    my $obj_hash = {id_run => $id_run, propagate_npg_tracking_schema => 1, tracking_schema => undef,};
    if ($lanes) { $obj_hash->{positions} = $lanes; }
    if ($what) { $obj_hash->{option} = $what; }
    $self->load_from_staging(npg_qc::autoqc::qc_store::query->new($obj_hash));
    return 1;
}


=head2 load_from_staging

De-serializes objects from JSON files found in staging area.
Adds these de-serialized objects to this collection.
Also see add_from_dir method.

 my $query =  npg_qc::autoqc::qc_store::query->new(id_run => 123);
 my $c = npg_qc::autoqc::results::collection->new();
 $c->load_from_staging($query);

How to define a query is described in documentation for npg_qc::autoqc::qc_store::query.

=cut
sub load_from_staging {
    my ($self, $query) = @_;

    if (!defined $query) {
      croak q[Query object should be defined];
    }

    my $finder_hash = {id_run => $query->id_run,};
    if ($query->propagate_npg_tracking_schema) {
        $finder_hash->{npg_tracking_schema} = $query->npg_tracking_schema;
    }

    my $finder = Moose::Meta::Class->create_anon_class(
       roles => [qw/npg_tracking::illumina::run::short_info
                    npg_tracking::illumina::run::folder/])->new_object($finder_hash);


    if ( $query->option == $LANES || $query->option == $ALL ) {
        $self->add_from_dir($finder->bustard_path, $query->positions, $query->id_run);
        $self->add_from_dir($finder->qc_path, $query->positions, $query->id_run);
    }

    if ( $query->option == $PLEXES || $query->option == $ALL ) {

        my @dirs = ();
        my @lanes = @{$query->positions};
        if ( @lanes ) {
            foreach my $lane ( @lanes ) {
                my $path = $finder->lane_qc_path($lane);
                if (-e $path) {
                    push @dirs, $path;
                }
            }
        } else {
            @dirs = @{$finder->lane_qc_paths};
        }

        foreach my $dir (@dirs) {
            $self->add_from_dir($dir, undef, $query->id_run);
        }
    }

    return 1;
}


=head2 is_empty

Tests whether the collection is empty, returns true or false.

 my $collection = npg_qc::autoqc::results::collection->new();
 $collection->is_empty();  #returns true

=cut
sub is_empty {
    my $self = shift;
    return !$self->empty;
}

sub _sort_by_id_run { ## no critic (RequireArgUnpacking)
    return ( $_[0]->id_run <=> $_[1]->id_run) ||
           ( $_[0]->position <=> $_[1]->position) ||
           ( (!defined $_[0]->tag_index && !defined $_[1]->tag_index) ? $EQUAL : (
               (defined $_[0]->tag_index  && defined $_[1]->tag_index) ? ($_[0]->tag_index <=> $_[1]->tag_index) : (
                   !defined $_[0]->tag_index ? $LESS : $MORE
               )
             )
           ) || ( $_[0]->check_name cmp $_[1]->check_name);
}
sub _sort_by_position { ## no critic (RequireArgUnpacking)
    return ( $_[0]->position <=> $_[1]->position) || ( $_[0]->check_name cmp $_[1]->check_name);
}
sub _sort_by_check_name { ## no critic (RequireArgUnpacking)
    return ($_[0]->check_name cmp $_[1]->check_name) || ($_[0]->position <=> $_[1]->position);
}


=head2 sort_collection

Sorts the collection (in place) on one of the attributes of the  npg_qc::autoqc::results::result object.
The accepted attributes: position, check_name. When sorting on one attribute, performs a
secondary sort on the another one. Changes the order of the objects returned by the results method.

 $collection->sort_collection();               #default sorting on position
 $collection->sort_collection(q[position]);    #explicit sorting on position
 $collection->sort_collection(q[check_name]);  #sorting on the check name

=cut
sub sort_collection {
    my ($self, $criterion) = @_;

    if (!defined $criterion) {
        $criterion = q[position];
    } else {
        if ($criterion !~ /id_run|position|check_name/xsmi)  {
            croak q[Can only sort based on either id_run or position or check_name];
        }
    }
    if ($self->size <= 1) {return;}
    my $sort_method = "_sort_by_$criterion";
    $self->sort_in_place(\&{$sort_method});
    return 1;
}


=head2 slice

Returns a collection object that is a subset of this collection object.
Chooses the object according to a specified criteria.
The accepted criteria are position, check_name, and class_name.
If this collection does not have any objects that satisfy the slicing criterion,
an empty collection is returned.

 my $lane_one_results = $collection->slice(q[position], 1);
 my $qX_results       = $collection->slice(q[class_name], q[qX_yield]);
 my $q40_results      = $collection->slice(q[check_name], q[q40 yield]);

=cut
sub slice {

    my ($self, $criterion, $value) = @_;

    if (!defined $criterion) { croak q[Cannot slice on undefined criterion]; }
    if (!defined $value)     { croak qq[Cannot slice on undefined $criterion value]; }

    if ($criterion !~ /position|check_name|class_name/smx) {
        croak q[Can only slice based on either position or check_name or class_name];
    }

    my $c = __PACKAGE__->new();

    foreach my $r (@{$self->results}) {
        if ($r->$criterion && $r->$criterion eq $value) {
            $c->add($r);
        }
    }
    return $c;
}


=head2 search

Searches the collection using the criteria specified in the argument hash
reference. Returns the search result as a new collection object, which can be
empty. The equals_byvalue method  of the npg_qc::autoqc::results::result is
used in comparing the objects in the collection to the criteria.

 my $objects = $collection->search({position => 2, id_run => 222,});

=cut
sub search {
    my ($self, $h) = @_;

    my $c = __PACKAGE__->new();
    foreach my $r (@{$self->results}) {
        if ($r->equals_byvalue($h)) {
            $c->add($r);
        }
    }
    return $c;
}


=head2 filter_by_positions

Takes a reference to a list with positions as an argument. Deletes from the
collection all result objects with a position attribute not in the given list.

=cut
sub filter_by_positions {

    my ($self, $lanes) = @_;

    my $i = $self->size() - 1;

    my $position;
    while ($i >= 0) {
        $position = $self->get($i)->position;
        if (none {/$position/smx} @{$lanes}) {
            $self->delete($i);
        }
        $i--;
    }

    return;
}

=head2 run_lane_map

Generates a hash map of all run numbers and positions in the collection.
The keys are 'id_run:position' strings, the values are anonimous hashes,
each containing a 'position' and 'id_run' entry

=cut
sub run_lane_map {
    my $self = shift;
    my $map = {};
    foreach my $result (@{$self->results}) {
        my $key = $result->rpt_key;
        if (!defined $map->{$key}) {
            $map->{$key} = {id_run => $result->id_run, position => $result->position,};
        }
    }
    return $map;
}

=head2 run_lane_collections

Generates a hash map of all run numbers, positions and tag indices in the collection.
The keys are 'id_run:position:tag_index' strings, the values are relevant sub-collections.

=cut
sub run_lane_collections {
    my $self = shift;
    my $map = {};
    foreach my $result (@{$self->results}) {
        my $key = $result->rpt_key;
        if (!defined $map->{$key}) {
            my $c = __PACKAGE__->new();
            $c->add($result);
            $map->{$key} = $c;
        } else {
            $map->{$key}->add($result);
        }
    }
    return $map;
}

=head2 run_lane_plex_flags

Returns a hash map where keys are rpt keys for lanes and values are booleans indicating
whether this lane has plex-level results.

=cut
sub run_lane_plex_flags {
    my $self = shift;
    my $map = $self->run_lane_collections;

    my $flags = {};
    foreach my $rpt_key (keys %{$map}) {
        my $rpt_h = npg_qc::autoqc::role::rpt_key->inflate_rpt_key($rpt_key);
        if (!defined $rpt_h->{'tag_index'}) { # it's a lane-level entry
            if (!exists $flags->{$rpt_key}) {
                my $has_plexes = any { $_ eq 'tag metrics' || $_ eq 'tag decode stats'}
                                 @{$map->{$rpt_key}->check_names()->{'list'}};
                $flags->{$rpt_key} = $has_plexes ? 1 : 0;
            }
        } else { # it's a plex-level entry
            my $lane_key = npg_qc::autoqc::role::rpt_key->lane_rpt_key_from_key($rpt_key);
            $flags->{$lane_key} = 1;
        }
    }
    return $flags;
}

=head2 check_names_map

A mapping of class names to actually available check names

=cut
sub check_names_map {
    my $self = shift;

    my $classes = {};
    my $seen = {};
    my $checks_list = npg_qc::autoqc::autoqc->checks_list;
    foreach my $check (@{$checks_list}) {
        $classes->{$check} = [];
    }

    foreach my $result (@{$self->results}) {
        my $class_name = $result->class_name;
        my $check_name = $result->check_name;
        if (!exists $classes->{$class_name}) {
            croak qq[Unknown class name $class_name];
        }
        if (!exists $seen->{$check_name}) {
            push @{$classes->{$class_name}}, $check_name;
            $seen->{$check_name} = 1;
        }
    }
    return $classes;
}

=head2 check_names

A reference to a list of all check names which have result objects
in this collection. The names in the list are ordered in the same way
as class names returned by npg_qc::autoqc::autoqc->checks_list

=cut
sub check_names {
    my $self = shift;

    my $classes = $self->check_names_map();
    my @check_names = ();
    my $map = {};
    foreach my $check (@{npg_qc::autoqc::autoqc->checks_list}) {
        push @check_names, @{$classes->{$check}};
        foreach my $name (@{$classes->{$check}}) {
            $map->{$name} = $check;
        }
    }
    return {'list' => \@check_names, 'map' => $map,};
}


no Moose;
__PACKAGE__->meta->make_immutable;


1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::AttributeHelpers

=item npg_qc::autoqc::qc_store::options

=item Carp

=item English

=item List::MoreUtils

=item Module::Pluggable::Object

=item Readonly

=item File::Basename

=item Moose::Meta::Class

=item npg_tracking::illumina::run::short_info

=item npg_tracking::illumina::run::folder

=item npg_qc::autoqc::autoqc

=item npg_qc::autoqc::qc_store::options

=item npg_qc::autoqc::qc_store::query

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Marina Gourtovaia

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
