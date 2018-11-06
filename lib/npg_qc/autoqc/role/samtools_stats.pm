package npg_qc::autoqc::role::samtools_stats;

use Moose::Role;
use Readonly;
use Carp;

with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';

Readonly::Array my @FILTER_VALUES4VISUALS => qw/F0x000 F0xB00/;

sub result4visuals {
  my ($self, $ss_results) = @_;

  $ss_results ||= [];
  my $result;

  my %filters = map { $_ => 1 } @FILTER_VALUES4VISUALS;
  foreach my $r ( grep { !$_->composition->get_component(0)->subset } @{$ss_results} ) {
    my $f = $r->filter;
    if ($filters{$f}) {
      if (ref $filters{$f}) {
        carp ref $filters{$f};
        croak "Multiple results for filter $f";
      }
      $filters{$f} = $r;
    }
  }

  foreach my $f ( @FILTER_VALUES4VISUALS ) {
    if (ref $filters{$f} ) {
      $result = $filters{$f};
      last;
    }
  }

  return $result;
}

no Moose::Role;

1;

__END__

=head1 NAME

npg_qc::autoqc::role::samtools_stats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 result4visuals

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd

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
