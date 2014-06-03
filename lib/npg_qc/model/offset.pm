#########
# Author:        gq1
# Created:       2009-01-20
#

package npg_qc::model::offset;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_all();

sub fields {
  return qw(
            id_offset
            id_run
            lane
            tile
            cycle
            image
            x
            y
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     $self->{lane} &&
     $self->{tile} &&
     $self->{cycle} &&
     $self->{image} &&
     !$self->{'id_offset'}) {

    my $query = q(SELECT id_offset
                  FROM   offset
                  WHERE  id_run= ?
                  AND    lane = ?
                  AND    tile = ?
                  AND    cycle = ?
                  AND    image = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->lane(), $self->tile(), $self->cycle(), $self->image());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_offset'} = $ref->[0]->[0];
    }
  }
  return 1;
}
sub offset_by_run_lane {
  my ($self) = @_;

  my $rows = [];
  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT tile, cycle, image, x, y
                  FROM offset 
                  WHERE id_run = ?
                  AND lane = ?
                  ORDER BY tile, cycle, image
                  };
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_run(), $self->lane());

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

npg_qc::model::offset

=head1 SYNOPSIS

  my $oOffset = npg_qc::model::offset->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

=head2 init

=head2 offset_by_run_lane

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
