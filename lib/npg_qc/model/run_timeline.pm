#########
# Author:        gq1
# Created:       2008-12-03
#

package npg_qc::model::run_timeline;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;

use npg::api::run_status;
use npg::api::util;

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_run_timeline
            id_run
            start_time
            complete_time
            end_time
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     !$self->{'id_run_timeline'}) {

    my $query = q(SELECT id_run_timeline
                  FROM   run_timeline
                  WHERE  id_run = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_run_timeline'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub npg_api_run_status {
  my ($self, $args) = @_;

  my $obj = $args->{run_status_obj};

  my $id_run = $args->{id_run};

  my $id_run_status_dict = $args->{id_run_status_dict};

  if ($obj) {
    $self->{npg_api_run_status} = $obj;
  } else {
    if ($self->{npg_api_run_status}
        && $id_run && $id_run_status_dict) {
        if ($self->{npg_api_run_status}->id_run() == $id_run && $self->{npg_api_run_status}->id_run_status_dict) {
          return $self->{npg_api_run_status};
        }
    } elsif (!$id_run) {
      return $self->{npg_api_run_status};
    } else {
      $self->{npg_api_run_status} = npg::api::run_status->new({
        'id_run' => $id_run,
        'id_run_status_dict' => $id_run_status_dict,
      });
    }
  }
  return $self->{npg_api_run_status};
}

1;
__END__
=head1 NAME

npg_qc::model::run_timeline

=head1 SYNOPSIS

  my $oMoveZ = npg_qc::model::run_timeline->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2  init

=head2 fields

=head2 npg_api_run_status

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
