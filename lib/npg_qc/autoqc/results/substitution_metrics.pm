package npg_qc::autoqc::results::substitution_metrics;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);
with    qw(npg_tracking::glossary::subset);

our $VERSION = '0';


has [qw/ ctoa_art_predicted_level 
      / ] => (
    is         => 'rw',
    isa        => 'Int',
);

has [qw/ titv_class
         titv_mean_ca 
         frac_sub_hq
         oxog_bias
         sym_gt_ca
         sym_ct_ga
         sym_ag_tc
         cv_ti
         gt_ti
         gt_mean_ti
         ctoa_oxh
       / ] => (
    is         => 'rw',
    isa        => 'Num',
);

has 'output_dir' => (is       => 'rw',
                     isa      => 'Str',
                     );



__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::results::substitution_metrics

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 GRL

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

