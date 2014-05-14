#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-01-19
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::model::frequency_response_matrix;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_all();

sub fields {
  return qw(
            id_frequency_response_matrix
            id_run
            cycle
            lane
            base
            red1
            red2
            green1
            green2
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     $self->{cycle} &&
     $self->{lane} &&
     $self->{base} &&
     !$self->{'id_frequency_response_matrix'}) {

    my $query = q(SELECT id_frequency_response_matrix
                  FROM   frequency_response_matrix
                  WHERE  id_run= ?
                  AND    cycle = ?
                  AND    lane = ?
                  AND    base = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->cycle(), $self->lane(), $self->base());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_frequency_response_matrix'} = $ref->[0]->[0];
    }
  }
  return 1;
}
sub response_matrix_by_run {
  my ($self) = @_;

  my $rows = [];
  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT cycle, lane, base, red1, red2, green1, green2
                  FROM frequency_response_matrix 
                  WHERE id_run = ?
                  ORDER BY cycle, lane, base
                  };
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_run());

    while (my @row = $sth->fetchrow_array()) {
      push @{$rows}, \@row;
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  return $rows;
}

1;
__END__
=head1 NAME

npg_qc::model::frequency_response_matrix

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oFrequency_response_matrix = npg_qc::model::frequency_response_matrix->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

=head2 init

=head2 response_matrix_by_run

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
Carp
Readonly

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
