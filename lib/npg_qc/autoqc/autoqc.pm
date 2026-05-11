package npg_qc::autoqc::autoqc;

use Moose;
use namespace::autoclean;
use Class::Load  qw(load_class);
use Getopt::Long qw(:config pass_through auto_version);
use Carp;

with 'MooseX::Getopt';

our $VERSION = '0';

has 'check' => (
  isa           => 'Str',
  is            => 'ro',
  required      => 1,
  documentation => q(Autoqc check name),
);

has 'spec'  => (
  isa           => 'Str',
  is            => 'ro',
  required      => 0,
  documentation => q(Name of a specific autoqc check in the namespace ) .
                   q(of the check given by the 'check' argument),
);

has 'only_if_can_run' => (
  isa           => 'Bool',
  is            => 'ro',
  required      => 0,
  default       => 0,
  documentation => q(If enabled, this option suppresses running the autoqc ) .
                   q(check if this check cannot be run for the given input. ) .
                   q(This option is disabled by default.),
);

sub create_check_object {
  my $self = shift;

  my $pkg = __PACKAGE__;
  my $delim = q[::];
  ($pkg) = $pkg =~ /(.+)${delim}(\w+)\Z/smx;
  $pkg = join $delim, $pkg, q[checks], $self->check;
  if ($self->spec) {
    $pkg = join $delim, $pkg, $self->spec;
  }
  load_class($pkg);
  my $check = $pkg->new_with_options();

  if ($self->only_if_can_run) {
    carp 'only_if_can_run option is enabled, checking if the check can run.';
    my $can_run = $check->can_run();
    carp sprintf 'Check for %s can%s run.',
      $check->to_string,
      $can_run ? q[] : q[not];
    $can_run || return;
  }

  return $check;
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

Creats an autoqc check object using arguments passed from a script described
in the above SYNOPSIS.

The C<--check> argument should be passed to a script to indicate the class
of the autoqc object to be created. The autoqc check class should
be defined in the C<npg_qc::autoqc::checks> namespace. If an object of
class C<npg_qc::autoqc::checks::mycheck> is required, use C<mycheck> as
the value of this argument.

To allow for specialisation under the umbrella of a particular check,
an optional C<--spec> script argument can be used in addition to the C<--check>
argument. With the C<--check> argument set to C<generic> and the C<--spec>
argument set to C<ampliconstats>, the factory returns an object of class
C<npg_qc::autoqc::checks::generic::ampliconstats>.

The C<only_if_can_run> argument can be used to suppress running the check
if it cannot be run. C<create_check_object> returns an undefined value in this
case.

All other script options are passed through unchanged to the constructor
of the autoqc check object.

=head1 SUBROUTINES/METHODS

=head2 check

The name of the check class, required attribute.

=head2 spec

The name of a specific check under the umbrella of a check name given
by the 'check' attribute. An optional attribute.

=head2 only_if_can_run

A boolean attribute, false by default.

=head2 create_check_object

Returns an instance of the autoqc check object of the class given
by the C<check> attribute. If C<only_if_can_run> is true, returns an undefined
value if, according to the check's C<can_run> method, the check cannot be run
for the given input.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Getopt

=item namespace::autoclean

=item Class::Load

=item Getopt::Long

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2015,2016,2020,2026 Genome Research Ltd.

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
