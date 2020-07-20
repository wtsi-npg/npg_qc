package npg_qc::autoqc::role::generic;

use Moose::Role;
use YAML::XS;

our $VERSION = '0';

around 'check_name' => sub {
  my $orig = shift;
  my $self = shift;
  return join q[ ], $self->$orig(), $self->pp_name || q[unknown];
};

around 'filename_root' => sub {
  my $orig = shift;
  my $self = shift;
  return join q[.], $self->$orig(), $self->pp_name || q[unknown];
};

sub doc2yaml {
  my $self = shift;
  my $doc = $self->doc;
  return $doc ? Dump($doc) : q[];
}

no Moose::Role;

1;

__END__

=head1 NAME

npg_qc::autoqc::role::generic

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 check_name

The original method is changed to append pp_name if defined.

=head2 filename_root

Changes the filename_root attribute of the parent class. The value
of the pp_name attribute is appended to the value produced
by the parent's method to allow for the results from different
pipelines to co-exist in the same directory.

=head2 doc2yaml

Returns a document hash as a YAML string.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item YAML::XS

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 Genome Research Ltd.

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
