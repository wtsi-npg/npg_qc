package npg_qc::autoqc::role::result;

use Moose::Role;
use Carp;
use File::Spec::Functions qw(catfile splitpath);
use JSON;
use MooseX::Storage;
use Readonly;
use List::MoreUtils qw(none uniq);

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => 'JSON',
              'io'     => 'File' ), 'npg_qc::autoqc::role::rpt_key';

our $VERSION = '0';

Readonly::Array my @SEARCH_PARAMETERS => qw/ position class_name check_name id_run tag_index /;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::role::result

=head1 SYNOPSIS

=head1 DESCRIPTION

This Moose role defines basic functionality of the autoqc result object.
It can be applied to classes of different origin, e.g to objects inheriting
from npg_qc::autoqc::results::base, from npg_qc::autoqc::results::result or
to a DBIx result class representing a row in a database table that stores
an autoqc result.

The class consuming this role should have the following accessors defined:
  composition,
  composition_digest,
  num_components.

=head1 SUBROUTINES/METHODS

=head2 class_name

Name of the class that did the check

=cut
sub class_name {
  my $self = shift;
  my ($ref) = (ref $self) =~ /(\w*)$/smx;
  if ($ref =~ /^[[:upper:]]/xms) {
    if ($ref eq 'QXYield') {
      $ref = 'qX_yield';
    } else {
      $ref =~ s/([[:lower:]])([[:upper:]])/$1_$2/gmxs;
      $ref = lc $ref;
    }
  }
  return $ref;
}

=head2 class_names

Converts autoqc package name or serialized class name to autoqc and DBIx result class names

=cut
sub class_names {
  my ($self, $name) = @_;
  if (!$self) {
    croak 'No arguments to class_names';
  }
  $name ||= (ref $self || $self);
  my ($class_name) = $name =~ /(\w+)(?:-\d+.*)?$/mxs;
  ##no critic (ProhibitParensWithBuiltins)
  my $dbix_class_name = join q[], map { ucfirst } split(/_/sm, $class_name);
  ##use critic
  return ($class_name, $dbix_class_name);
}

=head2 package_name

Name of the package that did the check

=cut
sub package_name {
  my $self = shift;
  return (ref $self);
}

=head2 check_name

Human readable check name

=cut
sub check_name {
  my $self = shift;
  my $name = $self->class_name;
  my $method = 'subset';
  if ($self->can($method) && $self->$method) {
    $name .= q{ } . $self->$method;
  }
  $method = 'check_name_local';
  if ($self->can($method)) {
    $name = $self->$method($name);
  }
  $name =~ s/_/ /gsmx;
  return $name;
}

=head2 composition_subset

A single, possibly undefined, value describing the subset attribute values
of the components. An error if a single value cannot be produced.

=cut
sub composition_subset {
  my $self = shift;

  my $token = 'none';
  my @subsets = uniq map { defined $_->subset ? $_->subset : $token }
                $self->composition->components_list;
  if (scalar @subsets == 0) {
    croak 'Composition is empty, cannot compute values for subset';
  }
  if (scalar @subsets > 1) {
    croak 'Multiple subsets within the composition: ' . join q[, ], @subsets;
  }
  my $subset = $subsets[0];

  return $subset eq $token ? undef : $subset;
}

=head2 get_rpt_list

Returns rn pt list value for a composition associated with the
result object.

=cut

sub get_rpt_list {
  my $self = shift;
  return $self->composition()->freeze2rpt();
}

=head2 equals_byvalue

Supports comparison on the following attributes:
  id_run, position, tag_index, check_name, class_name.

Returns true if this object has the properties listed in a hash.

 my $r = npg_qc::autoqc::results::result->new({id_run => 222, position => 2);
 $r->equals_byvalue({id_run => 222, position => 2});  # true
 $r->equals_byvalue({id_run => 222, position => 1});  # false
 $r->equals_byvalue({id_run => 222});                 # true
 $r->equals_byvalue({id_run => 222, tag_index => 1}); # false
 $r->equals_byvalue({check_name => 'result'});        # true

 my $component = npg_tracking::glossary::composition::component::illumina->new(
   id_run => 1, position => 2);
 my $f = npg_tracking::glossary::composition::factory->new();
 $f->add_component($c);
 my $r = npg_qc::autoqc::results::some->new(
   composition => $f->create_composition()
 );
 $r->equals_byvalue({id_run => 222, position => 1});  # false
 $r->equals_byvalue({id_run => 1, position => 2});    # true

=cut
sub equals_byvalue {
  my ($self, $other) = @_;

  if (!defined $other || ref $other ne 'HASH') {
    croak 'Can compare to HASH only';
  }

  my %test = %{$other};

  my @attrs = keys %test;
  if (!@attrs) {
    croak q[No parameters for comparison];
  }

  for my $attr (qw(class_name check_name)) {
    if ($test{$attr}) {
      if ($self->$attr ne $test{$attr}) {
        return 0;
      }
      delete $test{$attr};
    }
  }

  @attrs = keys %test;
  if (@attrs) {
    my $composition = $self->composition();
    if ($composition->num_components() > 1) {
      croak 'Not ready to deal with multi-component composition';
    }
    my $component = $composition->get_component(0);
    for my $attr (@attrs) {
      if (defined $test{$attr} && defined $component->$attr &&
        $component->$attr ne $test{$attr}) {
        return 0;
      }
      if ((!defined $test{$attr} && defined $component->$attr) ||
        (defined $test{$attr} && !defined $component->$attr)) {
        return 0;
      }
    }
  }

  return 1;
}

=head2 filename_root

A non-serializable attribute, a suggested filename root for storing the serialized object.

=cut

has 'filename_root' => (isa         => q[Str],
                        traits      => [ 'DoNotSerialize' ],
                        is          => q[ro],
                        required    => 0,
                        lazy_build  => 1,
                       );
sub _build_filename_root {
  my $self = shift;
  return $self->file_name; # from the moniker role
}

=head2 filename4serialization

Filename that should be used to write json serialization of this object to

=cut
sub filename4serialization {
  my $self = shift;
  return $self->file_name_full($self->filename_root,
                               ext => $self->class_name() . q[.json]);
}

=head2 thaw

Extends the parent method provided by the MooseX::Storage framework -
disables version checking between the version of the module that
serialized the object and the version of the same module that
is performing de-serialization. 

=cut
around 'thaw' => sub {
  my $orig = shift;
  my $self = shift;
  return $self->$orig(@_, 'check_version' => 0);
};

=head2 store

Extends 'store' method provided by inheritance.
Uses filename4serialization for default file name if none or directory is passed as argument.

=cut
around 'store' => sub {
  my ($orig, $self, $file) = @_;
  my $fn = $self->filename4serialization();
  $file = (not defined $file) ? $fn :
          -d $file            ? catfile($file,$fn) :
                                $file;
  return $self->$orig($file);
};

=head2 add_comment

Appends a comment to a string of comments
  
=cut
sub add_comment {
  my ($self, $comment) = @_;
  if ($comment) {
    if (!$self->comments) {
      $self->comments($comment);
    } else {
      $self->comments($self->comments . q[ ] . $comment);
    }
  }
  return;
}

=head2 to_string

Returns a human readable string representation of the object.

=cut
sub to_string {
  my $self = shift;
  return join q[ ], ref $self , $self->composition->freeze;
}

=head2 json

Serialization of this object to JSON.

=cut
sub json {
  my $self = shift;
  my $package_name = ref $self;
  if (!$package_name) {
    croak '"json" method should be called on an object instance';
  }
  if ($package_name =~ /Schema/xms) {
    my $h = {'__CLASS__' => $package_name};
    foreach my $column ($self->result_source->columns()) {
      $h->{$column} = $self->$column;
    }
    return to_json($h);
  }
  return $self->freeze();
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item File::Spec::Functions

=item JSON

=item MooseX::Storage

=item Readonly

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2015,2016,2017,2018,2019 Genome Research Ltd.

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
