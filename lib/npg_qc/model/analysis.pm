#########
# Author:        ajb
# Created:       2008-10-06
#

package npg_qc::model::analysis;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use base qw(npg_qc::model);
use npg_qc::model::analysis_lane;

our $VERSION = '0';
__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_many('analysis_lane');

sub fields {
  return qw(
            id_analysis
            id_run
            date
            folder
            iscurrent
          );
}

sub init {
  my ($self) = @_;

  if(!$self->{id_analysis} && $self->{id_run}) {
    my $q = q{SELECT id_analysis, date, folder FROM analysis WHERE id_run = ? AND iscurrent = 1};
    my $dbh = $self->util->dbh();
    my $ref = $dbh->selectall_arrayref($q, {}, $self->{id_run})->[0];
    if ($ref) {
      $self->{id_analysis} = $ref->[0];
      $self->{date}        = $ref->[1];
      $self->{folder}      = $ref->[2];
      $self->{iscurrent}   = 1;
    }
  }
  return 1;
}

1;
__END__
=head1 NAME

npg_qc::model::analysis


=head1 SYNOPSIS

  my $oAnalysis = npg_qc::model::analysis->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oAnalysisLane->fields();

=head2 init - populates the model via id_run if this is the argument passed to new

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Carp

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
