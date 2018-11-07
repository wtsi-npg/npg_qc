package npg_qc::autoqc::checks::gc_fraction;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use File::Basename;
use Try::Tiny;

use npg_tracking::util::abs_path qw(abs_path);
use npg_qc::autoqc::parse::samtools_stats;
use npg_qc::autoqc::constants qw/ $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER /;
use npg_common::sequence::reference::base_count;

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find);

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd RequireCheckingReturnValueOfEval ProhibitParensWithBuiltins)

=head1 NAME

npg_qc::autoqc::checks::gc_fraction

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check.

  my $check = npg_qc::autoqc::checks::gc_content->new(id_run => 33, position => 1);
  $check->execute();
  my $check = npg_qc::autoqc::checks::qX_yield->new(
    rpt_list => '33:1:2;33:2:2', is_paired_read => 1,
    qc_in => '/tmp', qc_out => '/tmp');

=head1 DESCRIPTION

Parses out gc percent for a sequence from a samtools stats file
and evaluates this value against the gc content of the reference genome.

=cut

Readonly::Scalar my $EXT        => 'stats';
Readonly::Scalar my $HUNDRED    => 100;
Readonly::Scalar my $APP        => q[npgqc];
Readonly::Scalar my $MAX_DELTA  => 20;
Readonly::Array  my @READS      => qw/ forward reverse /;

=head1 SUBROUTINES/METHODS

=head2 aligner

Overrides an attribute with the same name in npg_tracking::data::reference::find.
Defaults to te name of the application that will access the data, ie npgqc.

=cut

has '+aligner'        => (default => $APP,);

=head2 file_type

=cut

has '+file_type'      => (default => $EXT,);

=head2 suffix

Input file name suffix. The filter used in samtools stats command to
produce the input samtools stats file. Defaults to F0xB00.

=cut

has '+suffix' => (default => $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER,);

=head2 is_paired_read

Boolean flag indicating whether both a forward and reverse reads are present.
Defaults to true.
 
=cut

has 'is_paired_read'  => (isa       => 'Bool',
                          is        => 'ro',
                          predicate => 'has_is_paired_read',
                         );

=head2 ref_base_count_path

A path to a file with base count for the relevant reference genome.
Does not include teh extension.

=cut

has 'ref_base_count_path' => (isa         => 'Maybe[Str]',
                              is          => 'ro',
                              required    => 0,
                              lazy_build  => 1,
                             );
sub _build_ref_base_count_path {
    my $self = shift;

    my @refs;
    try {
        @refs = @{$self->refs()};
    } catch {
        $self->result->add_comment(q[Error: reference cannot be retrieved; cannot run gc content check. ] . $_);
    };

    if ($self->messages->count) {
        $self->result->add_comment(join(q[ ], $self->messages->messages));
    }

    if (scalar @refs > 1) {
	      $self->result->add_comment(q[multiple references found: ] . join(q[;], @refs));
        return;
    }

    if (scalar @refs == 0) {
        $self->result->add_comment(q[Failed to retrieve a reference.]);
        return;
    }

    return (pop @refs);
}

=head2 execute

=cut

override 'execute' => sub {
    my $self = shift;

    super();
    my $source_file = $self->input_files->[0];
    my $source_file_name = $self->generate_filename_attr->[0];

    my $ref_data_path;
    my $ref_gc_percent;
    if ($self->ref_base_count_path) {
        $ref_data_path = $self->ref_base_count_path . q[.json];
        if (-r $ref_data_path) {
            my $ref_base_count_hash = npg_common::sequence::reference::base_count
                                      ->load($ref_data_path)->summary->{'counts'};
            $ref_gc_percent = $self->_gc_percent($ref_base_count_hash);
        }
    }

    $self->result->threshold_difference($MAX_DELTA);

    my @apass = ();
    my $stats = npg_qc::autoqc::parse::samtools_stats->new(file_path => $source_file);

    my @reads = @READS;
    my $is_paired_read = $self->has_is_paired_read
                       ? $self->is_paired_read
                       : $stats->has_reverse_read;

    if (!$is_paired_read) {
        pop @reads;
    }

    foreach my $read ( @reads ) {
        my $base_percent = $stats->base_composition($read);
        my $gc = defined $base_percent ? ($base_percent->{'G'} + $base_percent->{'C'}) : 0;
        my $result_method = $read . q[_read_gc_percent];
        $self->result->$result_method($gc);
        my $filename_method =  $read . q[_read_filename];
        $self->result->$filename_method($source_file_name);
        if (defined $ref_gc_percent) {
            push @apass,
                (abs ($self->result->$result_method - $ref_gc_percent) < $MAX_DELTA ) ? 1 : 0;
        }
    }

    if (defined $ref_gc_percent) {
        $self->result->ref_gc_percent($ref_gc_percent);
    }
    if (defined $self->ref_base_count_path) {
        my ($filename, $directories, $suffix) = fileparse($self->ref_base_count_path);
        $self->result->ref_count_path(abs_path($directories), $filename);
    }

    if (@apass) {
        $self->result->pass($self->overall_pass(@apass));
    }

    return 1;
};

sub _gc_percent {
    my ($self, $base_count_hash) = @_;

    my $gc_percent = 0;
    if (exists $base_count_hash->{G}) {
        $gc_percent = $base_count_hash->{G};
    }
    if (exists $base_count_hash->{C}) {
        $gc_percent += $base_count_hash->{C};
    }
    my $total_percent = $gc_percent;
    if (exists $base_count_hash->{A}) {
        $total_percent += $base_count_hash->{A};
    }
    if (exists $base_count_hash->{T}) {
        $total_percent += $base_count_hash->{T};
    }

    my $result = 0;
    if ($total_percent != 0) {
        $result = $gc_percent/$total_percent * $HUNDRED;
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Readonly

=item Moose

=item namespace::autoclean

=item File::Basename

=item Try::Tiny

=item npg_tracking::util::abs_path

=item npg_tracking::data::reference::find

=item npg_common::sequence::reference::base_count

=item npg_common::fastqcheck

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
