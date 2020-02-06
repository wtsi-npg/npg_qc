package npg_qc::autoqc::results::collection;

use Moose;
use namespace::autoclean;
use MooseX::AttributeHelpers;
use List::MoreUtils qw(none);
use Module::Pluggable::Object;
use Carp;
use Readonly;

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
 $collection->slice(q[position], 3);
 $collection->search({check_name => 'insert size'});
 $collection->search({class_name => 'insert_size'});

=head1 DESCRIPTION

 A wrapper around a list of objects, which are derived from the npg_qc::autoqc::results::result object.
 Has methods for sorting, slicing and searching the collection.

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $RESULTS_NAMESPACE => q[npg_qc::autoqc::results];
Readonly::Array  my  @NON_LISTABLE      => map {join q[::], $RESULTS_NAMESPACE, $_}
                                                         qw/
                                                             sequence_summary
                                                             base
                                                             result
                                                             collection
                                                           /;

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
          'get'    => 'get',
          'grep'   => 'grep',
          'elements' => 'all',
      },
                 );

=head2 checks_list

A reference to a list of result classes.

=cut
has 'checks_list' => (isa        => 'ArrayRef',
                      is         => 'ro',
                      required   => 0,
                      lazy_build => 1,
                     );
sub _build_checks_list {
    my $load = 0;
    my @classes = Module::Pluggable::Object->new(
        require     => $load,
        search_path => $RESULTS_NAMESPACE,
        except      => \@NON_LISTABLE,
    )->plugins;
    my @class_names = ();
    my $bfs = 'bam_flagstats';
    foreach my $class (@classes) {
        my ($class_name) = $class =~ /(\w+)$/smx;
        if ($class_name ne $bfs) {
            push @class_names, $class_name;
        }
    }
    push @class_names, $bfs;
    return \@class_names;
}

=head2 add

Adds objects to the collection. The argument should be either one object or a reference
to an array of objects. If the latter, all objects in the array will be appended to the
collection in the order they are given. If no argument is supplied, the collection's state
does not change.

 my $collection = npg_qc::autoqc::results::collection->new();
 my $r = npg_qc::autoqc::results::insert_size->new(id_run => 222, position => 1);
 $collection->add($r);
 $collection->add([$r, $r]);
 $collection->add(); # nothing happens, no error either

Returns true if the collection state has changed, false otherwise.

=cut
sub add {
    my ($self, $r) = @_;
    if (defined $r) {
      ref $r eq q{ARRAY} ? $self->push(@{$r}) : $self->push($r);
      return 1;
    }
    return 0;
}

=head2 join_collections

Class method. Joins a list of collections given as attribute,
returns a collection object. Does not prune duplicates.

=cut
sub join_collections {
    my ($package, @collections) = @_;
    my $cln = __PACKAGE__->new();
    foreach my $c (@collections) {
        $cln->push(@{$c->results});
    }
    return $cln;
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

=head2 sort_collection

Sorts the collection (in place) on the check_name attribute of the result object.

 $collection->sort_collection();

=cut
sub sort_collection {
    my $self = shift;
    return $self->sort_in_place(sub { $_[0]->check_name cmp $_[1]->check_name });
}

=head2 slice

Returns a collection object that is a subset of this collection object.
Chooses the object according to a specified criterion.
If this collection does not have any objects that satisfy the slicing criterion,
an empty collection is returned.

 my $qX_results       = $collection->slice(q[class_name], q[qX_yield]);
 my $q40_results      = $collection->slice(q[check_name], q[q40 yield]);

=cut
sub slice {
    my ($self, $criterion, $value) = @_;
    if (!defined $criterion) {
        croak q[Cannot slice on undefined criterion];
    }
    if (!defined $value) {
        croak qq[Cannot slice on undefined $criterion value];
    }
    return $self->search({$criterion => $value});
}

=head2 remove

Utility method wrapping grep functionality to remove from collection those
elements matching criteria. Returns a new collection without the elements.

my $plex_results = $collection->remove(q[check_name], [ 'qX_yield', 'gc bias' ]);

=cut

sub remove {
    my ($self, $criterion, $values) = @_;

    if (!defined $criterion) { croak q[Cannot remove with undefined criterion]; }
    if (!defined $values)     { croak qq[Cannot remove with undefined $criterion values]; }

    if ($criterion !~ /check_name|class_name/smx) {
        croak q[Can only remove based on either check_name or class_name];
    }

    my $c = __PACKAGE__->new();
    my @filtered = $self->grep(sub { my $obj = $_; none { $obj->$criterion eq $_ } @{$values} } );
    $c->push(@filtered);

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

=head2 run_lane_collections

Generates a hash map of all run numbers, positions and tag indices in the collection.
The keys are rpt list strings, the values are relevant sub-collections.

=cut
sub run_lane_collections {
    my $self = shift;
    my $map = {};
    foreach my $result (@{$self->results}) {
        my $key = $result->get_rpt_list;
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

sub _check_names_map {
    my $self = shift;

    my $seen    = {};
    my $classes = {};
    foreach my $result (@{$self->results}) {
        my $class_name = $result->class_name;
        my $check_name = $result->check_name;
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
as class names returned by the checks_list() attribute.

=cut
sub check_names {
    my $self = shift;

    my $classes = $self->_check_names_map();
    my @check_names = ();
    my $map = {};
    foreach my $check (@{$self->checks_list}) { # To ensure order
        if ($classes->{$check}) {
            push @check_names, @{$classes->{$check}};
            foreach my $name (@{$classes->{$check}}) {
                $map->{$name} = $check;
            }
        }
    }
    return {'list' => \@check_names, 'map' => $map};
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

=item MooseX::AttributeHelpers

=item Carp

=item English

=item List::MoreUtils

=item Module::Pluggable::Object

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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
