package npg_qc_viewer::Util::Error;

use Moose::Role;
use namespace::autoclean;
use Carp;
use Readonly;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar my $ERROR_CODE_STRING   => q[SeqQC error code ];
Readonly::Scalar my $INTERNAL_ERROR_CODE => 500;

=head1 NAME

npg_qc_viewer::Util::Error

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role for creating, raising and parsing errors for this application.

=head1 SUBROUTINES/METHODS

=head2 raise_error

 Uses compose_error method to create an error message,
 then uses croak to raise the error.

 $obj->raise_error('some error', 401);
 $obj->raise_error('some error'); # error code 500 will be used

=cut

sub raise_error {
  my ($self, $message, $error_code) = @_;
  my $error = $self->compose_error($message, $error_code);
  croak $error;
}

=head2 compose_error

 Create and returns an error message. If teh error code is given,
 it is prepended to the message in a standard way.

 $obj->compose_error('some error', 401);
 $obj->compose_error('some error');

=cut

sub compose_error {
  my ($self, $message, $error_code) = @_;
  if (!$message) {
    croak 'Message should be given';
  }
  if ($error_code) {
    $message = $ERROR_CODE_STRING . $error_code. q[. ] . $message;
  }
  return $message;
}

=head2 parse_error

 For a standard SeqQC error message, returns teh actiol error message and
 the error code. For other error messages returns teh original message and code 500.

 my ($error, $error_code) = $obj->parse_error($some error);

=cut
sub parse_error {
  my ($self, $error_message) = @_;
  if (!$error_message) {
    croak 'Message should be given';
  }

  my $error_code;
  my $message = $error_message;
  ##no critic (RegularExpressions::RequireExtendedFormatting)
  my $contains_error_code = $error_message =~ s/\A$ERROR_CODE_STRING//sm;
  ##use critic
  if ($contains_error_code) {
    ($error_code, $message) = $error_message =~ /\A(\d+)[.][ ](.+)/smx;
  }
  $error_code ||= $INTERNAL_ERROR_CODE;
  return ($message, $error_code);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item namespace::autoclean

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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

