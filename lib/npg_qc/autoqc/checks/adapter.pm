#########
# Author:        Original copied from /software/pathogen/projects/protocols/lib/perl5/Protocols/QC/SlxQC.pm
# Created:       24 September 2009

package npg_qc::autoqc::checks::adapter;

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use File::Basename;
use File::Spec;
use Parallel::ForkManager;
use File::Temp qw( tempdir );
use POSIX qw(mkfifo);
use Fcntl qw(:mode);
use IPC::SysV qw(IPC_STAT IPC_PRIVATE);
use Readonly;

use npg_common::extractor::fastq qw/read_count/;
use npg_tracking::data::reference::list;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check);
with    qw(npg_common::roles::software_location);

our $VERSION = '0';

Readonly::Scalar our $LINES_PER_FASTQ_RECORD => 4;
Readonly::Scalar my $ADAPTER_FASTA => q[adapters.fasta];

Readonly::Scalar my $MINUS_ONE   => -1;
Readonly::Scalar my $SHIFT_EIGHT => 8;

#indices of different fields in the NCBI tabular blat output
Readonly::Scalar my $SEQ_NAME_IND => 0;
Readonly::Scalar my $REF_NAME_IND => 1;
# match indices are NOT zero based
Readonly::Scalar my $START_MATCH_IND => 6;
Readonly::Scalar my $END_MATCH_IND => 7;

has 'adapter_fasta'  => ( isa        => 'NpgTrackingReadableFile',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_adapter_fasta {
    my $self = shift;
    my $repos = Moose::Meta::Class->create_anon_class(
        roles => [qw/npg_tracking::data::reference::list/])->new_object()->adapter_repository;
    return File::Spec->catfile($repos, $ADAPTER_FASTA);
}

has 'aligner_path'  =>  ( is         => 'ro',
                          isa        => 'NpgCommonResolvedPathExecutable',
                          required   => 0,
                          coerce     => 1,
                          default    => q[blat],
                        );

has 'bamtofastq_path' => ( is         => 'ro',
                         isa        => 'NpgCommonResolvedPathExecutable',
                         required   => 0,
                         coerce     => 1,
                         default    => q[bamtofastq],
                       );

has 'adapter_list'  => (  is          => 'ro',
                          isa         => 'ArrayRef',
                          required    => 0,
                          lazy_build  => 1,
                        );
sub _build_adapter_list {
    my $self = shift;

    my $adapter_file = slurp $self->adapter_fasta();
    my @list = ();
    foreach ( split m/\n/msx, $adapter_file ) {
        my ($name) = m/^>(\S+)/msx;
        next if !$name;
        push @list, $name;
    }
    return \@list;
}

override 'execute' => sub {
    my ($self) = @_;
    if(!super()) {return 1;}

    my $short_fnames = $self->generate_filename_attr();
    my $i = 0;

    if ($self->file_type eq q[bam]) {
        my ($bam_in) = @{$self->input_files};
        my $results = $self->_search_adapters_from_bam($bam_in);
        $self->result->forward_read_filename($bam_in);
        $self->result->forward_contaminated_read_count($results->{forward}{contam_read_count});
        $self->result->forward_blat_hash($results->{forward}{contam_hash});
        $self->result->forward_start_counts($results->{forward}{adapter_starts});
        $self->result->reverse_read_filename($bam_in);
        $self->result->reverse_contaminated_read_count($results->{reverse}{contam_read_count});
        $self->result->reverse_blat_hash($results->{reverse}{contam_hash});
        $self->result->reverse_start_counts($results->{reverse}{adapter_starts});

    } else {
      foreach my $fastq ( @{$self->input_files} ) {
        $i++;
        my $read_count = read_count($fastq);
        my $read = ($i == 1) ? 'forward' : 'reverse';

        my $file_method = $read . q{_read_filename};
        $self->result->$file_method( $short_fnames->[$i-1] );
        $file_method = $read . q{_fasta_read_count};
        $self->result->$file_method($read_count);
        $file_method = $read . q{_blat_hash};
        $self->result->$file_method({});

        if (!$read_count) {
            $self->result->add_comment(qq[$fastq is empty]);
            next;
        }

        my $results = $self->_search_adapters($fastq);

        $file_method = $read . q{_contaminated_read_count};
        $self->result->$file_method($results->{contam_read_count});

        foreach my $adapter (@{ $self->adapter_list}) {
            if (!exists $results->{contam_hash}->{$adapter}) {
                $results->{contam_hash}->{$adapter} = 0;
	    }
        }
        $file_method = $read . q{_blat_hash};
        $self->result->$file_method($results->{contam_hash});

        $file_method = $read . q{_start_counts};
        $self->result->$file_method($results->{adapter_starts});
      }
    }

    return;
};

sub _blat_command {
    my $self = shift;
    return $self->aligner_path .  q[ ] . $self->adapter_fasta . q[ stdin stdout -tileSize=9 -maxGap=0 -out=blast8];
}

sub _search_adapters {
    my ($self, $fastq) = @_;


    my $command = q[/bin/bash -c "set -o pipefail && npg_fastq2fasta ] . qq[$fastq | ] . $self->_blat_command . q[" | ];
    ## no critic (ProhibitTwoArgOpen)
    open my $fh, $command or croak qq[Cannot fork '$command', error $ERRNO];
    ## use critic
    my $results = $self->_process_search_output($fh);
    close $fh or carp qq[cannot close bad pipe '$command'];

    my $child_error = $CHILD_ERROR >> $SHIFT_EIGHT;
    if ($child_error != 0) {
        croak qq[Error in pipe '$command': $child_error];
    }

    return $results;
}

sub _search_adapters_from_bam {
    my ($self, $bam) = @_;

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
    if (! $pid) { #fork to convert BAM to fastq then into fasta whilst count forward and reverse reads
      my ($fieldi, $fcount, $rcount) = (0,0,0);
      my $b2fqcommand = q[/bin/bash -c "set -o pipefail && ] . $self->bamtofastq_path .
                        qq[ T=$tmpdir/bamtofastq filename=$bam ] . q[" |] ;
      open my $ifh, $b2fqcommand or croak qq[Cannot fork '$b2fqcommand', error $ERRNO];
      open my $ofh, q(>), $tempfifo or croak qq[Cannot write to fifo $tempfifo, error $ERRNO];
      while (my $line = <$ifh>){
        $fieldi++;
        $fieldi%=$LINES_PER_FASTQ_RECORD;
        if ($fieldi==1){ #count forward/rev, print fasta identifier
          if ( substr($line, 0, 1, q(>)) ne q(@) ) {croak 'incorrect fastq format'}
          $line=~m{^\S+/2\b}smx ? $rcount++ : $fcount++;
          print {$ofh} $line or croak qq[Cannot write to fifo $tempfifo, error $ERRNO];
        }elsif($fieldi==2){ #print bases
          print {$ofh} $line or croak qq[Cannot write to fifo $tempfifo, error $ERRNO];
        }
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

    # Count the total number of contaminated reads and the number of reads
    # contaminated per adapter. The blat output is one line per read per
    # adapter match - i.e. a read matching two separate adapters, or matching
    # the same adapter twice, will have two entries. We rely heavily on the
    # output being sorted by read then by adapter.

    my $results = {};
    $results->{contam_hash} = {};
    $results->{adapter_starts} = {};
    $results->{forward} = {};
    $results->{forward}{contam_read_count} = 0;
    $results->{forward}{contam_hash} = { map {$_ => 0} @{$self->adapter_list} };
    $results->{forward}{adapter_starts} = {};
    $results->{reverse} = {};
    $results->{reverse}{contam_read_count} = 0;
    $results->{reverse}{contam_hash} = { map {$_ => 0} @{$self->adapter_list} };
    $results->{reverse}{adapter_starts} = {};
    my $read_count = 0;

    my ( $read, $match);
    my ( $previous_read, $previous_match) = ( q{ }, q{ } );

    my $start;
    my $previous_start = $MINUS_ONE;
    my $direction = q(forward); #forward/reverse

    while (my $lane = <$blat_fh>) {
        next if !$lane; # there might be no output

        my @fields = split m/\s+/msx, $lane;
        if (scalar @fields < $END_MATCH_IND + 1) {
	    croak q[Too few fields in blat output];
	}
        $match = $fields[$REF_NAME_IND];
        $read  = $fields[$SEQ_NAME_IND];
        $start = $fields[$START_MATCH_IND] < $fields[$END_MATCH_IND] ?
                    $fields[$START_MATCH_IND] : $fields[$END_MATCH_IND];

        if ( $read ne $previous_read ) {
            $direction = $read=~m{/2\z}smx ? q(reverse) : q(forward);
            $read_count++;
            $results->{$direction}{contam_read_count}++;
            $results->{contam_hash}->{$match}++;
            $results->{$direction}{contam_hash}{$match}++;
            if ($previous_start >= 0) {
	        $results->{adapter_starts}->{$previous_start} = exists $results->{adapter_starts}->{$previous_start} ? $results->{adapter_starts}->{$previous_start} + 1 : 1;
	        $results->{$direction}{adapter_starts}{$previous_start} = exists $results->{$direction}{adapter_starts}{$previous_start} ? $results->{$direction}{adapter_starts}{$previous_start} + 1 : 1;
	    }
	    $previous_start = $start;
            next;
        }

        if ( $match ne $previous_match ) {
            $results->{contam_hash}->{$match}++;
            $results->{$direction}{contam_hash}{$match}++;
        }
        if ($start < $previous_start) { $previous_start = $start; }

    }
    continue {
        ( $previous_read, $previous_match) = ( $read, $match);
    }
    if ($previous_start >= 0) {
        $results->{adapter_starts}->{$previous_start}++;
        $results->{$direction}{adapter_starts}{$previous_start}++;
    }

    $results->{contam_read_count} = $read_count;
    return $results;
}

no Moose;
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

    Look for adapter matches in fastq files. Right now there is only one tool
    for this (blat) but later versions may add others, or allow modification
    of the search parameters.
  
    Results for a forward and reverse read are reported separately.

=head1 SUBROUTINES/METHODS

=head2 BUILD last method called before returning a new instance of the object to the caller

=head2 new

    Moose-based. An optional argument, 'adapter_fasta',
    may be supplied to override the default list of adapter sequences used.

=head2 execute

    Over-ride the parent execute subroutine. Procedural code to find the
    fastq(s) for a run lane and run a blat search for adapter sequences in
    each one.

=head2 S_IRWXU - injected by IPC::SysV

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

    The class expects to find the blat executable installed at $BLAT_PATH

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item English

=item Perl6::Slurp

=item Readonly

=item File::Basename

=item File::Spec

=item IPC::SysV

=item npg_common::extractor::fastq

=item npg_tracking::data::reference::list

=item npg_tracking::util::types

=item npg_common::roles::software_location

=back

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

    Counting unique contaminated reads (totals and per adapter) is problematic
    with large, highly contaminated fastq files. This module saves on massive
    memory overheads by relying on the blat output file being sorted first on
    reads then on adapters.

=head1 AUTHOR

    John O'Brien, jo3

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by John O'Brien and Marina Gourtovaia

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
