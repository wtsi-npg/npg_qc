package npg_qc::mqc::outcomes;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use List::MoreUtils qw/ none /;
use Carp;

use npg_tracking::glossary::rpt;

our $VERSION = '0';

Readonly::Scalar my $NO_TAG_FLAG => -1;

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 1,
);

sub get {
  my ( $self, $qlist) = @_;

  if (!$qlist || (ref $qlist ne 'ARRAY')) {
    croak 'Input is missing or is not an array';
  }

  my $hashed_queries = {};
  foreach my $q ( @{$qlist} ) {
    _validate_query($q);
    my $tag = defined $q->{'tag_index'} ? $q->{'tag_index'} : $NO_TAG_FLAG;
    push @{$hashed_queries->{$q->{'id_run'}}->{$q->{'position'}}}, $tag;
  }

  my @lib_outcomes = ();
  my @seq_outcomes = ();

  foreach my $id_run ( keys %{$hashed_queries} ) {
    my @positions = keys %{$hashed_queries->{$id_run}};
    foreach my $p ( @positions ) {
      my @tags = @{$hashed_queries->{$id_run}->{$p}};
      my $query = {'id_run' => $id_run, 'position' => $p};
      if ( none {$_ == $NO_TAG_FLAG} @tags ) {
        $query->{'tag_index'} = \@tags;
      }
      my @lib_rows = $self->qc_schema()->resultset('MqcLibraryOutcomeEnt')
                     ->search($query, {'join' => 'mqc_outcome'})->all();
      if ( @lib_rows ) {
        push @lib_outcomes, @lib_rows;
      }
    }
    my $q = {'id_run' => $id_run, 'position' => \@positions};
    my @seq_rows = $self->qc_schema()->resultset('MqcOutcomeEnt')
                   ->search($q, {'join' => 'mqc_outcome'})->all();
    if ( @seq_rows ) {
      push @seq_outcomes, @seq_rows;
    }
  }

  my $h = {};
  $h->{'lib'} = _map_outcomes(\@lib_outcomes);
  $h->{'seq'} = _map_outcomes(\@seq_outcomes);

  return $h;
}

sub save {
  return;
}

sub _validate_query {
  my $q = shift;
  if (!defined $q->{'id_run'} || !defined $q->{'position'}) {
    croak q[Both 'id_run' and 'position' keys should be defined];
  }
  return;
}

sub _map_outcomes {
  my $outcomes = shift;
  my $map = {};
  foreach my $o (@{$outcomes}) {
    my $packed = $o->pack();
    $map->{npg_tracking::glossary::rpt->deflate_rpt($packed)} = $packed;
  }
  return $map;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc::mqc::outcomes

=head1 SYNOPSIS

  my $o = npg_qc::mqc::outcomes->new(qc_schema  => $qc_schema);
  $o->get($data_array);
  $o->save($data_array);

=head1 DESCRIPTION

Helper object for operations on QC outcomes (retrieval and saving).

=head1 SUBROUTINES/METHODS

=head2 qc_schema

DBIx npg qc schema object, required attribute.

=head2 get

Takes an array of queries. Each query hash should contain at least the 'id_run'
and 'position' keys and can also contain the 'tag_index' key.
 
Returns simple representations of rows hashed first on the type of
the outcome 'lib' for library outcomes and 'seq' for sequencing outcomes
and then on rpt keys.

  use Data::Dumper;
  print Dumper $obj->get([{id_run=>5,position=>3,tag_index=>7});

  $VAR1 = {
          'lib' => {
                     '5:3:7' => {
                                  'tag_index' => 7,
                                  'mqc_outcome' => 'Undecided final',
                                  'position' => 3,
                                  'id_run' => 5
                                }
                   },
          'seq' => {
                     '5:3' => {
                                'mqc_outcome' => 'Accepted final',
                                'position' => 3,
                                'id_run' => 5
                              }
                   }
          };

For a query with id_run and position the sequencing lane outcome and all known
library outcomes for this position are be returned. For a query with id_run,
position and tag_index both the sequencing lane outcome and library outcome are
returned. 

=head2 save

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item List::MoreUtils

=item Carp

=item npg_tracking::glossary::rpt

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
