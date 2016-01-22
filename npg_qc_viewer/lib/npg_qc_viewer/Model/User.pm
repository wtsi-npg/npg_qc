package npg_qc_viewer::Model::User;

use Moose;
use Carp;

BEGIN { extends 'Catalyst::Model' }

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Model::User

=head1 SYNOPSIS

  my $user_info = $context_obj->model('User')->logged_user($context_obj);
  my $uc = {username => 'cat', password => 'secret'};
  $user_info = $context_obj->model('User')->logged_user($context_obj, $uc);

=head1 DESCRIPTION

Catalyst model encapsulating authentication and authorisation for application
users.

=head1 SUBROUTINES/METHODS

=head2 logged_user

  $context_obj->model('User')->logged_user($context_obj);
  my $uc = {username => 'cat', password => 'secret'};
  $user_info = $context_obj->model('User')->logged_user($context_obj, $uc);

$user_info is a hash reference containing 'username' and 'has_mqc_role' keys.
If the user is not logged in or the authentication failed, the values for
both keys are empty strings. If the authentication was successful, the
'username' key points to the login name of the user. If the authenticated user
is authorised to do manual qc, the 'has_mqc_role' key is set to 1.

=cut

sub logged_user {
  my ($self, $c, $user_credentials) = @_;
  if (!$c) {
    croak 'Context object is missing';
  }
  $user_credentials ||= {};
  my $h = {'username' => q[], 'has_mqc_role' => q[]};
  if ($c->authenticate($user_credentials) && $c->user->username) {
    $h->{'username'}     = $c->user->username;
    $h->{'has_mqc_role'} = $c->check_user_roles(qw/manual_qc/) ? 1 : q[];
  }
  return $h;
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd.

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

