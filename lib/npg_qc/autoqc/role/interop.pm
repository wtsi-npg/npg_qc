package npg_qc::autoqc::role::interop;

use Moose::Role;
use Readonly;

our $VERSION = '0';

Readonly::Array my @METHODS => qw/

  aligned_mean
  aligned_stdev

  occupied_mean
  occupied_stdev

  cluster_count_total
  cluster_count_mean
  cluster_count_stdev

  cluster_pf_mean
  cluster_pf_stdev

  cluster_count_pf_total
  cluster_count_pf_mean
  cluster_count_pf_stdev

  cluster_density_mean
  cluster_density_stdev

  cluster_density_pf_mean
  cluster_density_pf_stdev
/;

my $create_methods = sub { # wrapped to scope $meta variable
  my $meta = __PACKAGE__->meta;
  for my $method (@METHODS) {
    $meta->add_method($method, sub {
      my $obj_ref = shift;
      return $obj_ref->metrics()->{$method};
    });
  }
};

$create_methods->();

no Moose::Role;

1;

__END__

=head1 NAME

npg_qc::autoqc::role::interop

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 aligned_mean
    
=head2 aligned_stdev
    
=head2 cluster_count_mean

=head2 cluster_count_pf_mean
  
=head2 cluster_count_pf_stdev
    
=head2 cluster_count_pf_total

=head2 cluster_count_stdev
 
=head2 cluster_count_total

=head2 cluster_density_mean
    
=head2 cluster_density_pf_mean
 
=head2 cluster_density_pf_stdev
  
=head2 cluster_density_stdev
   
=head2 cluster_pf_mean
    
=head2 cluster_pf_stdev
    
=head2 occupied_mean
 
=head2 occupied_stdev

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

Steven Leonard E<lt>srl@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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
