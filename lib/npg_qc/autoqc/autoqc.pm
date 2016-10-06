package npg_qc::autoqc::autoqc;

use Moose;
use namespace::autoclean;
use Class::Load  qw(load_class);
use Getopt::Long qw(:config pass_through auto_version);
use Carp;

with 'MooseX::Getopt';

our $VERSION = '0';

has 'check' => ( isa           => 'Str',
                 is            => 'ro',
                 required      => 1,
                 documentation => 'QC check name',
               );

sub create_check_object {
  my $self = shift;
  my $pkg = __PACKAGE__;
  my $delim = q[::];
  ($pkg) = $pkg =~ /(.+)${delim}(\w+)\Z/smx;
  $pkg = join $delim, $pkg, q[checks], $self->check;
  load_class($pkg);
  return $pkg->new_with_options();
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::autoqc::autoqc

=head1 SYNOPSIS

In a script:

  use npg_qc::autoqc::autoqc;
  my $check_obj = npg_qc::autoqc::autoqc->new_with_options()
                  ->create_check_object();
  $check_obj->run();

=head1 DESCRIPTION

A factory for creating an autoqc check object using script arguments.

The --check option should be passed to a script to indicate the class
of the autoqc object to be created. The autoqc check class should
be defined in the npg_qc::autoqc::checks namespace. If an object of
class 'npg_qc::autoqc::checks::mycheck' is required, use 'mycheck' as
the value of the --check attribute.

All other script options are passed through unchanged to the constructor
of the autoqc check object.

=head1 SUBROUTINES/METHODS

=head2 check

The name of the check class, required attribute.

=head2 create_check_object

Returns an instance of the autoqc check object of the class given
by the check attribute.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Getopt

=item namespace::autoclean

=item Class::Load

=item Getopt::Long

=item Carp

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
