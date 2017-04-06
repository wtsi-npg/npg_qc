package npg_qc::Schema::ResultSet;

use Moose;
use namespace::autoclean;
use MooseX::MarkAsMethods;
use Carp;

extends 'DBIx::Class::ResultSet';

our $VERSION = '0';

sub search_autoqc {
  my ($self, $query, $size) = @_;

  my $how = {'cache' => 1};
  # Copy the query so that we do not change the input data,
  # thus allowing the caller to reuse the variable representing
  # the query.
  my %local_values = %{$query};
  my $values = \%local_values;
  my $rsource = $self->result_source();
  if ($rsource->has_relationship('seq_component_compositions')) {
    foreach my $col_name  (keys %{$values}) {
      my $new_key = join q[.],
        $rsource->has_column($col_name) ? 'me' : 'seq_component', $col_name;
      $values->{$new_key} = $values->{$col_name};
      delete $values->{$col_name};
    }
    if ($size) {
      $values->{'seq_component_compositions.size'} = $size;
    }
    $how->{'prefetch'} = {'seq_component_compositions' => 'seq_component'};
  } else {
    my $ti_key = 'tag_index';
    if (exists $values->{$ti_key} && ($rsource->name() eq 'spatial_filter')) {
      delete $values->{$ti_key};
    }
    my $only_existing = 1;
    $self->deflate_unique_key_components($values, $only_existing);
  }
  my $rs = $self->search_rs($values, $how);
  return $rs;
}

sub deflate_unique_key_components {
  my ($self, $values, $only_existing) = @_;

  if (!defined $values) {
    croak q[Values hash should be defined];
  }
  if (ref $values ne q[HASH]) {
    croak q[Values should be a hash];
  }

  my $source = $self->result_source();
  my %constraints = $source->unique_constraints();
  my @names = grep {$_ ne 'primary'} keys %constraints;

  if (@names) {
    if (scalar @names > 1) {
      croak q[Multiple unique constraints in ] . $self->result_class;
    }
    foreach my $col_name (@{$constraints{$names[0]}}) {
      if ($only_existing && !exists $values->{$col_name}) {
        next;
      }
      my $default_value = $source->column_info($col_name)->{'default_value'};
      if (!defined $default_value) {
        next;
      }
      my $col_value = $values->{$col_name};
      if (!defined $col_value) {
        $values->{$col_name} = $default_value;
      } elsif (ref $col_value eq 'HASH') {
        my @keys = keys %{$col_value};
        my $key = pop @keys;
        if (@keys == 0 && $col_value->{$key} eq 'undef') {
          $values->{$col_name}->{$key} = $default_value;
        }
      }
    }
  }

  ################
  #
  # Temporary measure to push existing data through
  #

  ##no critic (ProhibitMagicNumbers)
  if  ($self->result_class eq 'npg_qc::Schema::Result::BamFlagstats' &&
      $values->{'library_size'} && $values->{'library_size'} == -1) {
    $values->{'library_size'} = undef;
  }
  ##use critic

  return;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
__END__

=head1 NAME

npg_qc::Schema::ResultSet

=head1 SYNOPSIS

=head1 DESCRIPTION

A parent class for ResultSet objects in npg_qc::Schema DBIx binding.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 search_autoqc

Transparently searches for autoqc objects irrespectedly of their database
implementation, i.e. the objects might have id_run, position, etc. values
in the table with the data or they can just link to the seq_composition table.

A ResultSet is returned in any context. The "cache" option is enabled for
the query.

The "size" argument is ignored if the table with the data is not linked
to the seq_composition table.

  my $rset = $rs->search_autoqc($query, $size);

Example for a table that is not linked to the seq_composition table.

  my $schema = npg_qc::Schema->connect();
  my $srs = $schema->resultset("InsertSize");

  # all rows for a lane
  $srs->search_autoqc({id_run => 17967, position => 1 });
  # all rows for a lane
  $srs->search_autoqc({id_run => 17967, position => 1 });
  # rows for a lane-level result
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => undef });
  # rows for tag 45 results
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45 });

If the table is linked to the seq_composition table and the "size" argument is not
defined or is zero, the search will be for all compositions that have a
component defined by the search query - the first argument.

Example for a table that is linked to the seq_composition table.

  $srs = $schema->resultset("SequenceSummary");

  # all rows for a lane
  $srs->search_autoqc({id_run => 17967, position => 1 });
  # rows for a lane-level result
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => undef });
  # rows for tag 45 results
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45 });
  # rows for tag 45 results, default subset
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45, subset => undef });
  # rows for tag 45 results, phix subset
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45, subset => 'phix' });
  # rows for tag 45 results, default subset where there is one component only
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45, subset => 'phix' }, size => 1);
  # rows for tag 45 results, default subset where the component the query defines is one of two components
  $srs->search_autoqc({id_run => 17967, position => 1, tag_index => 45, subset => 'phix' }, size => 2);

=head2 deflate_unique_key_components

Takes a hash key reference of column names and column values,
deflates unique key components if needed, ensuring that if this hash reference
is used for querying, correct results will be produced. Changes values in-place.
  
  my $rs = $schema->resultset('SomeTable');
  $rs->deflate_unique_key_components($values);

If the second boolean argument is true, will not deflate the values that are
not in the hash.

  my $only_existing = 1;
  $rs->deflate_unique_key_components($values, $only_existing);

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::MarkAsMethods

=item namespace::autoclean

=item Carp

=item DBIx::Class::ResultSet

=back

=head1 INCOMPATIBILITIES

This code does not work with MooseX::NonMoose hence false inline_constructor
option is used when calling ->make_immutable. This might make the code slower
than it could have been.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia <lt>mg8@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL Genome Research Limited

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

