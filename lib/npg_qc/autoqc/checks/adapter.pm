package npg_qc::autoqc::checks::adapter;

use Moose;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use File::Spec;
use Parallel::ForkManager;
use File::Temp qw(tempdir);
use POSIX qw(mkfifo);
use Fcntl qw(:mode);
use Readonly;
use List::MoreUtils qw(uniq);

use npg_tracking::data::reference::list;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check);
with    qw(npg_common::roles::software_location);

our $VERSION = '0';

Readonly::Scalar my $EXT => q[cram];
Readonly::Scalar my $ADAPTER_FASTA => q[adapters.fasta];

Readonly::Scalar my $SHIFT_EIGHT => 8;

#indices of different fields in the NCBI tabular blat output
Readonly::Scalar my $SEQ_NAME_IND => 0;
Readonly::Scalar my $REF_NAME_IND => 1;
# match indices are NOT zero based
Readonly::Scalar my $START_MATCH_IND => 6;
Readonly::Scalar my $END_MATCH_IND => 7;

has '+file_type'       => (default => $EXT,);

has 'adapter_fasta'    => ( isa        => 'NpgTrackingReadableFile',
                            is         => 'ro',
                            required   => 0,
                            lazy_build => 1,
                          );
sub _build_adapter_fasta {
    my $self = shift;
    my $repos = Moose::Meta::Class->create_anon_class(
        roles => [qw/npg_tracking::data::reference::list/])->new_object()->adapter_repository;
    return File::Spec->catfile($repos, $ADAPTER_FASTA);
}

has 'aligner_path'    => ( is        => 'ro',
                           isa        => 'NpgCommonResolvedPathExecutable',
                           required   => 0,
                           coerce     => 1,
                           default    => q[blat],
                         );

has 'adapter_list'    => ( is          => 'ro',
                           isa         => 'ArrayRef',
                           required    => 0,
                           lazy_build  => 1,
                         );
sub _build_adapter_list {
    my $self = shift;

    my @adapter_file = slurp $self->adapter_fasta();
    my @list = ();
    foreach my $line ( @adapter_file ) {
        $line =~ s/\s+\Z//smx;
        $line or next;
        my ($name) = $line =~ m/\A>(\S+)/msx;
        $name or next;
        push @list, $name;
    }
    my $n = scalar @list;
    @list = uniq @list;
    (scalar @list == $n) or croak 'Invalid adapter fasta file';

    return \@list;
}

override 'execute' => sub {
    my ($self) = @_;

    super();

    my ($cram_in) = @{$self->input_files};
    my $results = $self->_search_adapters_from_cram($cram_in);
    $self->result->forward_read_filename($cram_in);
    $self->result->forward_contaminated_read_count($results->{'forward'}{'contam_read_count'});
    $self->result->forward_blat_hash($results->{'forward'}{'contam_hash'});
    $self->result->forward_start_counts($results->{'forward'}{'adapter_starts'});
    $self->result->reverse_read_filename($cram_in);
    $self->result->reverse_contaminated_read_count($results->{'reverse'}{'contam_read_count'});
    $self->result->reverse_blat_hash($results->{'reverse'}{'contam_hash'});
    $self->result->reverse_start_counts($results->{'reverse'}{'adapter_starts'});

    return;
};

sub _blat_command {
    my $self = shift;
    return $self->aligner_path .  q[ ] . $self->adapter_fasta . q[ stdin stdout -tileSize=9 -maxGap=0 -out=blast8];
}

sub _search_adapters_from_cram {
    my ($self, $cram) = @_;

    my $tmpdir = File::Temp->newdir(); #will be removed when out of scope
    my $tempfifo = File::Temp::tempnam($tmpdir, q(fifo));
    mkfifo($tempfifo, S_IRWXU) or croak "Cannot create fifo $tempfifo";

    my $pm = Parallel::ForkManager->new(1, $tmpdir);
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
        $self->result->forward_fasta_read_count($data_structure_reference->{forward_count});
        $self->result->reverse_fasta_read_count($data_structure_reference->{reverse_count});
    });

    my $pid = $pm->start;
    ## no critic (ProhibitTwoArgOpen InputOutput::RequireBriefOpen)
    if (! $pid) { #fork to convert CRAM to fasta whilst counting forward and reverse reads
        my $b2fqcommand = q[/bin/bash -c "set -o pipefail && ] . $self->samtools_cmd .
                         qq[ fasta -F0x900 --thread 2 $cram] . q[" |] ;
        open my $ifh, $b2fqcommand or croak qq[Cannot fork '$b2fqcommand', error $ERRNO];
        open my $ofh, q(>), $tempfifo or croak qq[Cannot write to fifo $tempfifo, error $ERRNO];
        my ($fcount, $rcount) = (0,0);
        my $header_flag = 1;
        while (my $line = <$ifh>){
            if ($header_flag){
                $line =~ m{^\S+/2\b}smx ? $rcount++ : $fcount++;
            }
            # If this is header, the next line is not and other way around
            $header_flag = not $header_flag;
            print {$ofh} $line or croak qq[Cannot write to fifo $tempfifo, error $ERRNO];
        }
        close $ofh or croak qq[Cannot close fifo $tempfifo, error $ERRNO];
        close $ifh or croak qq[Cannot close pipe $b2fqcommand, error $ERRNO];
        $pm->finish(0,{forward_count => $fcount, reverse_count => $rcount}); # send counts
    }

    my $command = qq[/bin/bash -c "set -o pipefail && cat $tempfifo | ] . $self->_blat_command . q[" |];
    open my $fh, $command or croak qq[Cannot fork '$command', error $ERRNO];
    my $results = $self->_process_search_output($fh);
    close $fh or carp qq[cannot close bad pipe '$command'];
    ## use critic

    my $child_error = $CHILD_ERROR >> $SHIFT_EIGHT;
    if ($child_error != 0) {
        croak qq[Error in pipe '$command': $child_error];
    }

    $pm->wait_all_children;

    return $results;
}

sub _process_search_output {
    my ($self, $blat_fh) = @_;

    # Count the total number of contaminated reads and the number of
    # contaminated reads per adapter. The blat output is one line per read
    # per adapter match, i.e. a read matching two separate adapters, or
    # matching the same adapter twice will have two entries. We rely heavily
    # on the output being sorted by read, then by adapter.

    my $results = {};
    $results->{'forward'}{'contam_read_count'} = 0;
    $results->{'forward'}{'contam_hash'} = { map {$_ => 0} @{$self->adapter_list} };
    $results->{'forward'}{'adapter_starts'} = {};
    $results->{'reverse'}{'contam_read_count'} = 0;
    $results->{'reverse'}{'contam_hash'} = { map {$_ => 0} @{$self->adapter_list} };
    $results->{'reverse'}{'adapter_starts'} = {};

    my ($previous_read, $previous_match) = ( q{ }, q{ });
    my $previous_start;
    my $previous_direction;
    my $current_direction;

    while (my $lane = <$blat_fh>) {
        next if !$lane; # there might be no output

        my @fields = split m/\s+/msx, $lane;
        if (scalar @fields < $END_MATCH_IND + 1) {
            croak q[Too few fields in blat output];
        }

        my $match = $fields[$REF_NAME_IND];
        my $read  = $fields[$SEQ_NAME_IND];
        my $start = ($fields[$START_MATCH_IND] < $fields[$END_MATCH_IND]) ?
                    $fields[$START_MATCH_IND] : $fields[$END_MATCH_IND];

        if ( $read ne $previous_read ) { # new read starts, including the first read
            if ($previous_start) { # nothing to save for the first read
                $results->{$previous_direction}{'adapter_starts'}{$previous_start}++;
            }
            $current_direction = $read=~m{/2\z}smx ? q(reverse) : q(forward);
            $results->{$current_direction}{'contam_read_count'}++;
            $results->{$current_direction}{'contam_hash'}{$match}++;
            $previous_start = $start; # first start position for this read
        } else {
            if ($start < $previous_start) { # keep the lowest start position
                $previous_start = $start;
            }
            # match to the same reference can be reported multiple times
            if ( $match ne $previous_match ) {
                $results->{$current_direction}{'contam_hash'}{$match}++;
            }
        }

        ($previous_read, $previous_match, $previous_direction) = ($read, $match, $current_direction);
    } # end of reading blat output

    # save start position for the last read
    if ($previous_start) {
        $results->{$previous_direction}{'adapter_starts'}{$previous_start}++;
    }

    return $results;
}

__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::adapter - check for adapter sequences in fastq files.

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::adapter;

    The path to the fastq files must be specified along with the lane
    position.

    C<<my $adapter_check =
        npg_qc::autoqc::checks::adapter->new( path     = '/some/fastq/dir',
                                              position = 3, );>>

    You can override the default adapter list, either in the constructor or
    afterwards.

    C<<$adapter_check->adapter_fasta('list.fasta');>>

    Carry out a blat-based search.

    C<<$adapter_check->execute();>>

=head1 DESCRIPTION

    Look for adapter matches in cram files.
    Results for a forward and reverse read are reported separately.

=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based. An optional argument, 'adapter_fasta',
    may be supplied to override the default list of adapter sequences used.

=head2 execute

    Over-ride the parent execute subroutine. Procedural code to find the
    fastq(s) for a run lane and run a blat search for adapter sequences in
    each one.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

    The class expects to find the blat executable installed.

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English

=item Perl6::Slurp

=item Readonly

=item Parallel::ForkManager

=item File::Temp

=item POSIX

=item Fcntl

=item File::Spec

=item List::MoreUtils

=item npg_tracking::data::reference::list

=item npg_tracking::util::types

=item npg_common::roles::software_location

=back

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

    Counting unique contaminated reads (totals and per adapter) is problematic
    with large, highly contaminated files. This module saves on massive memory
    memory overheads by relying on the blat output file being sorted first on
    reads then on adapters.

=head1 AUTHOR

    John O'Brien, jo3

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
