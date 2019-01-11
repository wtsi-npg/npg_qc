package npg_qc::utils::genotype_calling;

use Moose::Role;
use Carp;
use English qw( -no_match_vars );
use Readonly;
use File::Spec::Functions qw(catdir catfile updir);
use Vcf;
use IO::File;
use Data::Dump qw(pp);

our $VERSION = '0';

Readonly::Scalar my $DEFAULT_MIN_BASE_QUAL  => 20;
Readonly::Scalar my $DEFAULT_MIN_CALL_DEPTH => 4;
Readonly::Scalar my $DEFAULT_CMD_DELIM      => q[ | ];
Readonly::Scalar my $BCFTOOLS               => q[bcftools];
Readonly::Scalar my $UNKNOWN                => q[Unknown];
Readonly::Scalar my $NO_CALL                => q[No Call];
Readonly::Scalar my $FEMALE                 => q[F];
Readonly::Scalar my $MALE                   => q[M];
Readonly::Scalar my $SEX_UNKNOWN            => q[U];
Readonly::Scalar my $MISSING                => q[.];
Readonly::Scalar my $FF_REF                 => q[X];
Readonly::Scalar my $FF_ALT                 => q[Y];
Readonly::Scalar my $HEADER_SAMPLE_MATCH    => q[FORMAT];

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

has 'create_fluidigm' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_create_fluidigm],
);
sub _build_create_fluidigm{
  my ($self) = shift;
  return $self->genotype_info->{'create_fluidigm'} // 0;
}

has 'regions_index_jump' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_regions_index_jump],
);
sub _build_regions_index_jump{
  my ($self) = shift;
  return $self->genotype_info->{'regions_index_jump'} // 0;
}

has 'add_alt_to_vcf' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_add_alt_to_vcf],
);
sub _build_add_alt_to_vcf{
  my ($self) = shift;
  return $self->genotype_info->{'add_alt_to_vcf'} // 0;
}

has 'sex_markers' => (
  is      => q[ro],
  isa     => q[HashRef],
  lazy    => 1,
  builder => q[_build_sex_markers],
);
sub _build_sex_markers{
  my ($self) = shift;
  return $self->genotype_info->{'sex_markers'} // {};
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
  if($self->genotype_info->{'filters'}){
    $filters = $self->genotype_info->{'filters'};
  }else{
    $filters->{'LowDepth'} = qq[FORMAT/DP<$DEFAULT_MIN_CALL_DEPTH];
  }
  return $filters;
}

has 'expected_sample_name' =>
(
  is      => q[ro],
  isa     => q[Str | Undef],
  lazy    => 1,
  builder => q[_build_expected_sample_name],
);
sub _build_expected_sample_name {
  my ($self) = @_;

  my $name;
  if($self->genotype_info->{'expected_sample_field'}){
    my $type = $self->genotype_info->{'expected_sample_field'};
    $name = $self->lims->$type;
    if (!$name || $name !~ /\S/smx){
      croak qq[No expected sample name found using requested $type];
    }
  }
  return $name;
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




sub run_calling {

  my ($self) = shift;

  $self->_pre_calling_checks;

  my $generate_vcf_cmd = $self->_generate_vcf_cmd;
  $self->result->set_info('Calling_command',$generate_vcf_cmd);

  my $vcf_results;
  open my $f, q{-|}, qq{$generate_vcf_cmd} or croak q[Failed to execute check];
  while(<$f>){ $vcf_results .= $_ };
  close $f or croak q[Failed to close check];

  $self->write_output($self->_temp_vcf,$vcf_results);
  $self->write_output($self->vcf_outfile,$self->_parsed_vcf);

  if($self->create_fluidigm){
    $self->write_output($self->ff_outfile,$self->_vcf_to_ff);
  }

  $self->_save_calling_metrics;
  return;
}

sub write_output {
  my($self,$file,$output) = @_;

  my $fh = IO::File->new($file,'>') or croak qq[cannot open $file];
  print {$fh} $output or croak qq[cant write to $file, error $ERRNO];
  $fh->close or croak qq[cannot close file $file: $ERRNO];

  return;
}


####################
# private attributes
####################
has '_metrics' => (
  traits  => ['Hash'],
  isa     => 'HashRef',
  is      => 'ro',
  default => sub { {} },
  handles => {
    _set_metric    => 'set',
    _get_metric    => 'get',
    _delete_metric => 'delete',
  },
);

has _annotation_regions_list => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_annotation_regions_list],
  init_arg => undef,
);
sub _build_annotation_regions_list {
  my $self = shift;

  my @regions;
  my $va = Vcf->new(file => $self->annotation_path);

  $va->parse_header;
  while (my $x = $va->next_data_hash()){
     push @regions, $x->{'CHROM'} .q[:]. $x->{'POS'} .q[-]. $x->{'POS'};
  }
  return join q[,], @regions;
}

has '_checked_alignments_in_bam' => (
  is      => q[ro],
  isa     => q[Bool],
  lazy    => 1,
  builder => q[_build_checked_alignments_in_bam],
);
sub _build_checked_alignments_in_bam {
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

has '_temp_vcf' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_temp_vcf],
);
sub _build_temp_vcf {
  my ($self) = @_;
  return catfile($self->tmp_path(), q[temp.vcf]);
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

  my $regions = $self->regions_index_jump ?
      q[ --regions ']. $self->_annotation_regions_list .q['] :
      q[ --targets-file ]. $self->annotation_path;

  my $mpileup_cmd =
      $self->bcftools . q[ mpileup].
      q[ --min-BQ ] . $self->min_base_qual .
      q[ --annotate 'FORMAT/AD,FORMAT/DP'].
      q[ --max-depth 50000 ].
      $regions .
      q[ --fasta-ref ]. $self->reference_fasta .
      q[ --output-type u ].
      q[ ]. $self->bam_file;

  ## TODO - check cmd length won't cause cmd line limit to be exceeded
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
    ($self->ploidy_path ? q[ --ploidy-file ]. $self->ploidy_path : q[]).
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
  my($self) = shift;

  my $va = Vcf->new(file => $self->annotation_path);
  my $vc = Vcf->new(file => $self->_temp_vcf);

  my (%tr, %results, $sex, $parsed, $reheader);
  my $sm = $self->sex_markers;

  $vc->parse_header;

  if($self->expected_sample_name) {
    my (@samples) = $vc->get_samples();
    if (@samples != 1) {
      croak q[More than 1 sample found in the VCF header];
    }
    elsif ( $samples[0] ne $self->expected_sample_name) {
      $reheader = $samples[0];
    }
  }

  $parsed = $vc->format_header;
  while (my $x = $vc->next_data_hash()){
    $tr{$x->{'CHROM'}. q[-] .$x->{'POS'}} = $x;
  }

  $va->parse_header;
  while (my $v = $va->next_data_hash()){
    $results{'genotypes_attempted'}++;

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

    if($self->add_alt_to_vcf && $k->{'ALT'}->[0] eq $MISSING){
      $k->{'ALT'}->[0] = $v->{'ALT'}->[0];
    }
    $parsed .= $vc->format_line($k);

    if($k->{'INFO'}->{'AN'} == 2){
      $results{'genotypes_called'}++;
      if(defined $sm->{$v->{'ID'}}) { $results{'sex_markers_called'}++ };
    }

    if($k->{'FILTER'}->[0] eq 'PASS'){
      $results{'genotypes_passed'}++;
      if($sm->{$v->{'ID'}}){
        $results{'sex_markers_passed'}++;

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

  if ($sex) { $self->result->sex($sex); }
  $self->_set_metric('sex_markers_attempted' => keys %{$self->sex_markers} // 0);
  foreach my $key (keys %results){
     $self->_set_metric($key => $results{$key} // 0);
  }

  ## switch default name in VCF header to the required one if requested
  ## - could use bcftools reheader instead.
  if($reheader){
    my $expected = $self->expected_sample_name;
    $parsed =~ s/$HEADER_SAMPLE_MATCH\t$reheader/$HEADER_SAMPLE_MATCH\t$expected/smx;
  }

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
  my($self) = shift;

  my $va = Vcf->new(file => $self->annotation_path);
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

sub _pre_calling_checks {
  my ($self) = shift;

  if(!defined($self->reference_fasta) || (! -r $self->reference_fasta)) {
		croak q[Reference genome missing or unreadable];
  }

  if(!$self->annotation_path) {
    croak q[No plex annotation file is found];
  }

  if(!$self->_checked_alignments_in_bam) {
    croak q[Input file is not aligned];
  }

  return;
}

sub _generate_vcf_cmd {
  my $self = shift;

  my $cmd = join $self->cmd_delim, $self->_mpileup_command,
                  $self->_call_command, $self->_filter_command;
  return $cmd;
}

sub _save_calling_metrics {
  my $self = shift;

  foreach my $key (@{$self->calling_metrics_fields()}) {
      my $value = $self->_get_metric($key);
      $self->result->$key($value // 0);
      $self->_delete_metric($key);
   }
   return;
}

no Moose::Role;

1;

__END__


=head1 NAME

    npg_qc::utils::genotype_calling

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 run_calling

=head2 write_output

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role
 
=item Carp

=item English

=item Readonly

=item File::Spec::Functions

=item Vcf

=item IO::File

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

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
