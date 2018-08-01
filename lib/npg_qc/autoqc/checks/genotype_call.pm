package npg_qc::autoqc::checks::genotype_call;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use JSON;
use Readonly;
use IO::File;
use IO::All;
use File::Spec::Functions qw(catdir catfile updir);
use Try::Tiny;
use Vcf;

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::gbs_plex::find
        npg_common::roles::software_location);

our $VERSION = '0';

Readonly::Scalar my $DEFAULT_MIN_BASE_QUAL   => 20;
Readonly::Scalar my $DEFAULT_MIN_CALL_DEPTH  => 4;
Readonly::Scalar my $DEFAULT_PASS_CALL_RATE  => 0.7;
Readonly::Scalar my $BCFTOOLS                => q[bcftools];
Readonly::Scalar my $UNKNOWN                 => q[Unknown];
Readonly::Scalar my $NO_CALL                 => q[No Call];
Readonly::Scalar my $DEFAULT_CMD_DELIM       => q[ | ];
Readonly::Scalar my $FEMALE                  => q[F];
Readonly::Scalar my $MALE                    => q[M];
Readonly::Scalar my $SEX_UNKNOWN             => q[U];
Readonly::Scalar my $MISSING                 => q[.];
Readonly::Scalar my $FF_REF                  => q[X];
Readonly::Scalar my $FF_ALT                  => q[Y];

has '+file_type' => (default => q[bam],);
has '+aligner'   => (default => q[fasta],);

has 'bcftools' => (
  is      => q[ro],
  isa     => q[NpgCommonResolvedPathExecutable],
  coerce  => 1,
  default => $BCFTOOLS,
);

has 'min_base_qual' => (
  is      => q[ro],
  isa     => q[Str],
  default => $DEFAULT_MIN_BASE_QUAL,
);

has 'cmd_delim' => (
  is      => q[ro],
  isa     => q[Str],
  default => $DEFAULT_CMD_DELIM,
);

has 'bam_file' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_bam_file],
);
sub _build_bam_file {
  my ($self) = shift;
  return $self->input_files->[0];
}


has 'reference_fasta' => (
  is      => q[ro],
  isa     => q[Str | Undef],
  lazy    => 1,
  builder => q[_build_reference_fasta],
);
sub _build_reference_fasta {
  my ($self) = shift;
  return $self->refs->[0];
}


has 'alignments_in_bam' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_alignments_in_bam],
);
sub _build_alignments_in_bam {
  my $self = shift;

  my $aligned = 0;

  my $command = $self->samtools_cmd . ' view -H ' . $self->bam_file . ' |';
  my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
  while (my $line = <$ph>) {
    if (!$aligned && $line =~ /^\@SQ/smx) {
      $aligned = 1;
    }
    last if $aligned;
  }
  $ph->close;

  return $aligned;
}


has 'output_dir' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_output_dir],
);
sub _build_output_dir {
  my $self = shift;
  return catdir($self->qc_out , updir);
}


has 'pass_call_rate' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_pass_call_rate],
);
sub _build_pass_call_rate {
  my ($self) = shift;
  return $self->_gbs_plex_info->{'pass_call_rate'} // $DEFAULT_PASS_CALL_RATE;
}


has 'filters' => (
  is      => q[ro],
  isa     => q[HashRef],
  lazy    => 1,
  builder => q[_build_filters],
);
sub _build_filters {
  my ($self) = shift;

  my $filters = {};
  if($self->_gbs_plex_info->{'filters'}){
    $filters = $self->_gbs_plex_info->{'filters'};
  }else{
    $filters->{'LowDepth'} = qq[FORMAT/DP<$DEFAULT_MIN_CALL_DEPTH];
  }
  return $filters;
}


has 'create_fluidigm' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_create_fluidigm],
);
sub _build_create_fluidigm{
  my ($self) = shift;
  return $self->_gbs_plex_info->{'create_fluidigm'} // 0;
}


has 'sex_markers' => (
  is      => q[ro],
  isa     => q[HashRef],
  lazy    => 1,
  builder => q[_build_sex_markers],
);
sub _build_sex_markers{
  my ($self) = shift;
  return $self->_gbs_plex_info->{'sex_markers'} // {};
}


has 'temp_vcf' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_temp_vcf],
);
sub _build_temp_vcf {
  my ($self) = @_;
  return catfile($self->tmp_path(), q[temp.vcf]);
}


has 'vcf_outfile' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_vcf_outfile],
);
sub _build_vcf_outfile {
  my ($self) = @_;
  return catfile($self->output_dir,
        $self->result->filename_root .q[.vcf])
}


has 'ff_outfile' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_ff_outfile],
  documentation => q[Fake fluidigm format file],
);
sub _build_ff_outfile {
  my ($self) = @_;
  return catfile($self->output_dir,
        $self->result->filename_root .q[.geno])
}


override 'can_run' => sub {
  my $self = shift;

  if(!$self->gbs_plex_name) {
    $self->result->add_comment('No gbs_plex_name is defined');
    return 0;
  }

  if ($self->lims->library_type && $self->lims->library_type !~ /^GbS/isxm) {
    $self->result->add_comment('Unexpected library_type : ' . $self->lims->library_type);
    return 0;
  }

  if (!$self->lims->sample_name) {
    $self->result->add_comment('Can only run on a single sample');
    return 0;
  }

  return 1;
};


override 'execute' => sub {
  my ($self) = @_;

  super();

  if(!$self->can_run()) {
    return 1;
  }

  if(!defined($self->reference_fasta) || (! -r $self->reference_fasta)) {
		croak q[Reference genome missing or unreadable];
  }

  if(!$self->alignments_in_bam) {
    croak q[BAM file is not aligned];
  }

  if(!$self->gbs_plex_annotation_path) {
    croak q[No plex annotation file is found];
  }

  $self->result->gbs_plex_name($self->gbs_plex_name);
  $self->result->gbs_plex_path($self->gbs_plex_annotation_path);
  $self->result->set_info('Caller',$self->bcftools);
  $self->result->set_info('Criterion',
           q[Genotype passed rate >= ]. $self->pass_call_rate);

  try {
    my $generate_vcf_cmd = $self->_generate_vcf_cmd;
    $self->result->set_info('Calling_command',$generate_vcf_cmd);

    my $vcf_results;
    open my $f, q{-|}, qq{$generate_vcf_cmd} or croak q[Failed to execute check];
    while(<$f>){ $vcf_results .= $_ };
	  close $f or croak q[Failed to close check];

    $self->_write_output($self->temp_vcf,$vcf_results);
    $self->_write_output($self->vcf_outfile,$self->_parsed_vcf);

    if($self->create_fluidigm){
      ## separate out vcf to fluidigm - assuming it will be short term
      $self->_write_output($self->ff_outfile,$self->_vcf_to_ff);
    }

    (($self->result->genotypes_passed/
     $self->result->genotypes_attempted) >= $self->pass_call_rate) ?
     $self->result->pass(1) : $self->result->pass(0);

    1;
  } catch {
    croak qq[ERROR calling genotypes : $_];
  };

  $self->result->add_comment(join q[ ], $self->messages->messages);

  return 1;
};



####################
# private attributes
####################

has '_gbs_plex_info' => (
  is       => q[ro],
  isa      => q[HashRef],
  lazy     => 1,
  builder  => q[_build_gbs_plex_info],
  init_arg => undef,
);

sub _build_gbs_plex_info {
  my ($self) = shift;
  my $info = {};
  if($self->gbs_plex_info_path){
     $info = decode_json(io($self->gbs_plex_info_path)->slurp);
  }
  return $info;
}

has '_mpileup_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_mpileup_command],
  init_arg => undef,
);

sub _build_mpileup_command {
  my ($self) = shift;

  my $mpileup_cmd =
      $self->bcftools . q[ mpileup].
      q[ --min-BQ ] . $self->min_base_qual .
      q[ --annotate 'FORMAT/AD,FORMAT/DP'].
      q[ --max-depth 50000 ].
      q[ --targets-file ]. $self->gbs_plex_annotation_path .
      q[ --fasta-ref ]. $self->reference_fasta .
      q[ --output-type u ].
      q[ ]. $self->bam_file;

  return $mpileup_cmd;
}

has '_call_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_call_command],
  init_arg => undef,
);

sub _build_call_command {
  my ($self) = shift;

  my $call_cmd =
    $self->bcftools . q[ call ].
    q[ --multiallelic-caller --keep-alts --skip-variants indels ].
    ($self->gbs_plex_ploidy_path ? q[ --ploidy-file ]. $self->gbs_plex_ploidy_path : q[]).
    q[ --output-type u ];

  return $call_cmd;
}

has '_filter_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_filter_command],
  init_arg => undef,
);

sub _build_filter_command {
  my ($self) = shift;

  my $filters = $self->filters;

  my @filter_cmds;
  foreach my $f(keys %{$filters}){
    push @filter_cmds,
    $self->bcftools . q[ filter ].
    q[ --mode + ].
    q[ --soft-filter ]. $f .
    q[ --exclude ']. $filters->{$f} .q['].
    q[ --output-type v ];
  }
  return join $self->cmd_delim, @filter_cmds;
}

has _parsed_vcf => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_parsed_vcf],
  init_arg => undef,
);

sub _build_parsed_vcf {
  my($self) = @_;

  my $va = Vcf->new(file => $self->gbs_plex_annotation_path);
  my $vc = Vcf->new(file => $self->temp_vcf);

  my (%tr, %results, $sex, $parsed);
  my $sm = $self->sex_markers;

  $vc->parse_header;
  $parsed = $vc->format_header;
  while (my $x = $vc->next_data_hash()){
    $tr{$x->{'CHROM'}. q[-] .$x->{'POS'}} = $x;
  }

  $va->parse_header;
  while (my $v = $va->next_data_hash()){
    $results{'attempted'}++;

    if(! $tr{$v->{'CHROM'} .q[-]. $v->{'POS'}}){
      $v->{'ALT'} = [$MISSING];
      $parsed .= $va->format_line($v);
      if($sm->{$v->{'ID'}}){
        $sex .= $SEX_UNKNOWN;
      }
      next;
    }

    my $k = $tr{$v->{'CHROM'} .q[-]. $v->{'POS'}};
    $k->{'ID'} = $v->{'ID'};
    $parsed .= $vc->format_line($k);

    if($k->{'INFO'}->{'AN'} == 2){
      $results{'called'}++;
      $sm->{$v->{'ID'}} ? $results{'scalled'}++ : q[];
    }

    if($k->{'FILTER'}->[0] eq 'PASS'){
      $results{'passed'}++;
      if($sm->{$v->{'ID'}}){
        $results{'spassed'}++;

        my $n = join q[], $vc->split_gt($vc->decode_genotype($k->{'REF'},
            $k->{'ALT'}, $k->{'gtypes'}->{$vc->get_samples}->{'GT'}));
        $n eq $sm->{$v->{'ID'}}->{$MALE} ? ($sex .= $MALE) :
            $n eq $sm->{$v->{'ID'}}->{$FEMALE} ? ($sex .= $FEMALE) : ($sex .= $SEX_UNKNOWN);
      }
    }elsif($sm->{$v->{'ID'}}){
      $sex .= $SEX_UNKNOWN;
    }

  }

  $va->close;
  $vc->close;

  defined $sex ? $self->result->sex($sex) : q[];

  $self->result->sex_markers_attempted(keys %{$self->sex_markers} // 0);
  $self->result->sex_markers_called($results{'scalled'} // 0);
  $self->result->sex_markers_passed($results{'spassed'} // 0);

  $self->result->genotypes_attempted($results{'attempted'} // 0);
  $self->result->genotypes_called($results{'called'} // 0);
  $self->result->genotypes_passed($results{'passed'} // 0);

  return $parsed;
}


has _vcf_to_ff => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_vcf_to_ff],
  init_arg => undef,
);

sub _build_vcf_to_ff
{
  my($self) = @_;

  my $va = Vcf->new(file => $self->gbs_plex_annotation_path);
  my $vc = Vcf->new(file => $self->vcf_outfile);
  my (%tr, $fakef, @res,);

  $va->parse_header;
  while (my $x = $va->next_data_hash()){
    if (@{$x->{'ALT'}} != 1 || $x->{'ALT'}->[0] eq $MISSING || $x->{'REF'} eq $MISSING){
      $self->messages->push(qq[Reference file format for $x->{'ID'} incompatible with ff.]);
    }else{
      $tr{$x->{'ID'}} = [$x->{'REF'},$x->{'ALT'}->[0]];
    }
  }

  $vc->parse_header;
  while (my $v = $vc->next_data_hash()){
    next if !$tr{$v->{'ID'}};

    my ($xy, @g,);
    if($v->{'FILTER'}->[0] eq 'PASS'){
      @g = $vc->split_gt($vc->decode_genotype($v->{'REF'},
         $v->{'ALT'}, $v->{'gtypes'}->{$vc->get_samples}->{'GT'}));

      my %gm = ($tr{$v->{'ID'}}->[0] => $FF_REF, $tr{$v->{'ID'}}->[1] => $FF_ALT);
      my $ch = join q[], keys %gm;

      $xy    = join q[], map{ s/([$ch])/$gm{$1}/rmxs; } @g;
    }

    @res = ($self->rpt_list,
            $v->{'ID'},
            $tr{$v->{'ID'}}->[0],
            $tr{$v->{'ID'}}->[1],
            $vc->get_samples,
            $UNKNOWN,);

    if(!$xy || $xy =~ /[^$FF_REF|^$FF_ALT]/mxs){
      push @res, $NO_CALL, 0, $NO_CALL, $NO_CALL, 0, 0;

    }else{
      my $rdf = sprintf '%.4f',
                  [split /\,/xms, $v->{'gtypes'}->{$vc->get_samples}->{'AD'}]->[0]/
                  $v->{'gtypes'}->{$vc->get_samples}->{'DP'};

      my $adf = sprintf '%.4f', (1 - $rdf);

      push @res, $xy, $v->{'QUAL'}, $xy, join(q[:], @g), $rdf, $adf;
    }
    $fakef .= join(qq[\t], @res) . qq[\n];
  }
  return $fakef;
}


#####################
# private subroutines
#####################

sub _generate_vcf_cmd {
  my($self) = shift;

  my $cmd = join $self->cmd_delim, $self->_mpileup_command,
                  $self->_call_command, $self->_filter_command;

  return $cmd;
}

sub _write_output {
  my($self,$file,$output) = @_;

  my $fh = IO::File->new($file,'>') or croak qq[cannot open $file];
  print {$fh} $output or croak qq[cant write to $file, error $ERRNO];
  $fh->close or croak qq[cannot close file $file: $ERRNO];

  return;
}


__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

    npg_qc::autoqc::checks::genotype_call

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::genotype_call;

=head1 DESCRIPTION

    Call genotypes in gbs_plex data

=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item English

=item Carp

=item JSON

=item Readonly

=item IO::File

=item IO::All

=item File::Spec::Functions

=item Try::Tiny

=item Vcf

=item npg_tracking::data::gbs_plex::find

=item npg_common::roles::software_location

=back

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
