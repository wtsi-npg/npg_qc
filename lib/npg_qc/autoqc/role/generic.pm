package npg_qc::autoqc::role::generic;

use Moose::Role;

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

sub massage_for_render {
  my $self = shift;

  my %table_data = ();
  if (exists $self->doc->{'QC summary'}) {
    my $qc_data = $self->doc->{'QC summary'} || {};

    foreach my $allowed_key (qw/
      longest_no_N_run pct_N_bases qc_pass pct_covered_bases
    /) {
      if (exists $qc_data->{$allowed_key}) {
        $table_data{$allowed_key} = $qc_data->{$allowed_key};
      } else {
        $table_data{$allowed_key} = q();
      }
    }
    # rename fields to improve viewer comprehension
    $table_data{num_aligned_fragments} = $qc_data->{num_aligned_reads};
  }
  if (exists $self->doc->{meta}) {
    # All current analyses that use this particular data are paired-end
    # and as such, the input fragment count does not reflect it.
    # Single-ended fragment counts will be incorrect!
    if (defined $self->doc->{meta}{num_input_reads}) {
      $table_data{num_input_fragments} = $self->doc->{meta}{num_input_reads} * 2;
    }

    $table_data{max_negative_control_filtered_read_count} =
      $self->doc->{meta}{max_negative_control_filtered_read_count} || q();

    my $sample_type = $self->doc->{meta}{sample_type};

    if ($sample_type eq 'positive_control') {
      $table_data{control_type} = 'positive';
    } elsif ($sample_type eq 'negative_control') {
      $table_data{control_type} = 'negative';
    }
  }

  return \%table_data;
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

=head2 massage_for_render

Takes stored ncov2019-artic-nf data and modifies it slightly for
rendering in the template.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

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
