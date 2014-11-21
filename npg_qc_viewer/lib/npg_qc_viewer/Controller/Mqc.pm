package npg_qc_viewer::Controller::Mqc;

use Moose;
use namespace::autoclean;
use Readonly;
use English qw(-no_match_vars);

BEGIN { extends 'Catalyst::Controller' }

our $VERSION  = '0';
## no critic (ProhibitBuiltinHomonyms)

Readonly::Array our @PARAMS  => qw/status 
                                   batch_id
                                   position
                                   lims_object_id
                                   lims_object_type
                                  /;

Readonly::Scalar our $BAD_REQUEST_CODE    => 400;
Readonly::Scalar our $INTERNAL_ERROR_CODE => 500;
Readonly::Scalar our $METHOD_NOT_ALLOWED  => 405;
Readonly::Scalar our $ALLOW_METHOD  => q[POST];
Readonly::Scalar our $MQC_ROLE  => q[manual_qc];

sub log : Path('log') {
    my ( $self, $c ) = @_;
    use Test::More;
    my $request = $c->request;
    if ($request->method ne $ALLOW_METHOD) {
        $c->response->headers->header( 'ALLOW' => $ALLOW_METHOD );
        _error($c, $METHOD_NOT_ALLOWED,
             qq[Manual QC action logging error: only $ALLOW_METHOD requests are allowed.]);
    }
    $c->controller('Root')->authorise($c, ($MQC_ROLE));

    my $referrer_url = $request->referer;
    if (!$referrer_url) {
      _error($c, $BAD_REQUEST_CODE,
        q[Manual QC action logging error: referrer header should be set.]);
    }
    my ( $id_run ) = $referrer_url =~ m{(\d+)\z}xms;
    if (!$id_run) {
      _error($c, $INTERNAL_ERROR_CODE,
	qq{Manual QC action logging error: failed to get id_run from referrer url $referrer_url});
    }

    my $values = {};
    $values->{'referer'} = $referrer_url;
    $values->{'user'} = $c->user->id;

    my $params = $request->body_parameters;
    foreach my $param (@PARAMS) {
        if ($param =~ /^batch_id|position$/smx ) {
            if($params->{$param}) {
                $values->{$param} = $params->{$param};
	    }
	} else {
            if(!$params->{$param}) {
                _error($c, $BAD_REQUEST_CODE,
                      qq[Manual QC action logging error: $param should be defined.]);
	    }
            if ($param eq q[status]) {
                my $status = $params->{$param};
                if ($status !~ /^fail|pass/smx) {
		  _error($c, $BAD_REQUEST_CODE,
                    qq[Manual QC action logging error: invalid status $status.]);
		}
                $values->{$param} = $status =~ /^pass/smx ? 1 : 0;
	    } else {
                $values->{$param} = $params->{$param};
	    }
	}
    }
    eval {
        $c->model('NpgDB')->log_manual_qc_action($values);
        $c->model('NpgDB')->update_lane_manual_qc_complete(
	  $id_run, $values->{'position'}, $values->{'status'}, $c->user->username);
        1;
    } or do {
        my $error = $EVAL_ERROR;
        _error($c, $INTERNAL_ERROR_CODE,
             qq[Error when logging manual qc action: $error]);
    };

    $c->response->body(q[Manual QC ] . $values->{status} . q[ for ] . $values->{lims_object_type} . q[ ] . $values->{lims_object_id} . q[ logged by NPG.]);
    return;
}

sub _error {
  my ($c, $code, $message) = @_;
  return $c->controller('Root')->detach2error($c, $code, $message);
}

1;
__END__

=head1 NAME

npg_qc_viewer::Controller::Mqc

=head1 SYNOPSIS

=head1 DESCRIPTION

A Catalyst Controller for logging manual qc actions,

=head1 SUBROUTINES/METHODS

=head2 index - action for an index page ~/mqc

=head2 log - logging action ~/mqc/log

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item English

=item namespace::autoclean

=item Moose

=item Catalyst::Controller

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

This file is part of NPG software.

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
