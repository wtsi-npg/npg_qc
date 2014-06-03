# Author:        Kevin Lewis
# Created:       2013-09-02
#
#

package npg_qc::autoqc::checks::upstream_tags;

use Moose;
use Carp;
use File::Basename;
use File::Spec::Functions qw(catfile catdir);
use List::MoreUtils qw { any };
use DBI;
use Readonly;
use FindBin qw($Bin);

use npg_qc::autoqc::checks::tag_metrics;
use npg_qc::autoqc::qc_store;
use npg_qc::utils::iRODS;
use npg_qc::autoqc::types;

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find
        npg_common::roles::software_location
       );

our $VERSION = '0';

Readonly::Scalar my $SAMTOOLS_NAME => q[samtools_irods];
Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $BARCODE_FILENAME => q[sanger168.tags];
Readonly::Scalar my $BARCODE_5BASES_FILENAME => q[sanger168_5.tags];
Readonly::Scalar my $BARCODE_6BASES_FILENAME => q[sanger168_6.tags];
Readonly::Scalar my $BID_JAR_NAME    => q[BamIndexDecoder.jar];
Readonly::Scalar my $NUM_BACK_RUNS => 5;
Readonly::Scalar my $MAX_MISMATCHES_DEFAULT => 1;
Readonly::Scalar my $MAX_NO_CALLS_DEFAULT => 0;
Readonly::Scalar my $VERBOSITY_DEFAULT => 1;
Readonly::Scalar my $VERBOSITY_LEVEL_3 => 3;
Readonly::Scalar my $DB_LOOKUP_DEFAULT => 1;
Readonly::Scalar my $MAX_RUNS  => 10;
Readonly::Scalar my $MIN_MATCH_PERCENT  => 0.00001;

Readonly::Scalar my $ID_RUN_POS  => 0;
Readonly::Scalar my $STATUS_DATE_POS  => 1;
Readonly::Scalar my $ID_INSTRUMENT_POS  => 2;
Readonly::Scalar my $INSTRUMENT_NAME_POS  => 3;
Readonly::Scalar my $SLOT_POS  => 4;

Readonly::Scalar our $DEFAULT_JAVA_XMX => q{-Xmx1000m};

has '+input_file_ext' => (default => $EXT,);

##############################################################################
# Input/output paths
#  By default, the pipeline supplies the archive path under the Latest_Summary
#  directory (the path attribute value is set via the qc_in value). This is
#  used to lazy-build the input output paths below
##############################################################################

#############################################################
# in_dir: lane_path and archive_qc_path are derived from this
#############################################################
has 'in_dir'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_in_dir {
	my $self = shift;

	my $ip = $self->path;

	return $ip;
}

########################################
# out_dir: cal_path is derived from this
########################################
has 'out_dir'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_out_dir {
	my $self = shift;

	my $op = $self->path;

	return $op;
}

#####################################################################################################
# Three paths used to locate input files and where to output auxiliary data:
#    i) cal_path - where the metrics_output file will be written; derived from out_dir by default
#   ii) lane_path - where the input tag#0 bam file is located; derived from in_dir by default
#  iii) archive_qc_path - where the tag_metrics results for the current run/lane are located; derived
#                           from in_dir by default
#####################################################################################################

##################################################################################################
# cal_path
#  PB_cal_bam or no_cal directory.
#   In the default pipeline case, removing the trailing archive element of the path will result in
#   the correct location.
##################################################################################################
has 'cal_path'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_cal_path {
	my $self = shift;

	my $rp = $self->out_dir;
	$rp =~ s{/archive$}{}smx;

	return $rp;
}

###########################################
# lane_path (for output of auxiliary data)
#  Directory containing the tag#0 bam file.
###########################################
has 'lane_path'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_lane_path {
	my $self = shift;

	my $lp_root = $self->in_dir;
	$lp_root =~ s{/archive$}{}smx;

	my $lp = sprintf q[%s/lane%d/], $lp_root, $self->position;

	return $lp;
}

#########################################################################################
# archive_qc_path (input data)
#  directory containing qc results (JSON) for the run. Used to locate tag_metrics results
#   for the current run/lane.
#########################################################################################
has 'archive_qc_path'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_archive_qc_path {
	my $self = shift;

	my $rp = $self->in_dir;
	$rp .= q[/qc];

	return $rp;
}

##############################################################################
# tag0_bam_file (input data)
#  type should be something like 'NpgTrackingReadableFile', but that currently
#   doesn't cope with iRODS paths
##############################################################################
has 'tag0_bam_file'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_tag0_bam_file {
	my $self = shift;

	my $lane_path = $self->lane_path;
	## no critic qw(ControlStructures::ProhibitUnlessBlocks)
	unless($lane_path =~ m{/$}smx) {
		$lane_path .= q[/];
	}
	## use critic
	my $basefilename = sprintf q[%s_%s#0.bam], $self->id_run, $self->position;

	my $file = $lane_path . $basefilename;

	if(! -f $file) {
		carp q[Looking in irods for bam file];

		$file = sprintf q[irods:/seq/%s/%s], $self->id_run, $basefilename;
	}

	return $file;
}

###############################################################
#  num_back_runs - how many previous runs should be reported on
###############################################################
has 'num_back_runs' => ( isa => 'NpgTrackingNonNegativeInt',
                         is => 'rw',
                         default => $NUM_BACK_RUNS,
                       );

###############################################################
#  max_mismatches: BamIndexDecoder parameter
###############################################################
has 'max_mismatches' => ( isa => 'NpgTrackingNonNegativeInt',
                         is => 'rw',
                         default => $MAX_MISMATCHES_DEFAULT,
                       );

###############################################################
#  max_no_calls: BamIndexDecoder parameter
###############################################################
has 'max_no_calls' => ( isa => 'NpgTrackingNonNegativeInt',
                         is => 'rw',
                         default => $MAX_NO_CALLS_DEFAULT,
                       );

#########################################################
#  total_tag0_reads - total read count for tag#0 bam file
#########################################################
has 'total_tag0_reads' => ( isa => 'NpgTrackingNonNegativeInt',
			is => 'ro',
			required   => 0,
			lazy_build  => 1,
                       );
sub _build_total_tag0_reads {
	my $self = shift;

	my $total_reads = 0;
	for my $read_count (values %{$self->tag0_BamIndexDecoder_metrics->result->reads_pf_count}) {
		$total_reads += $read_count;
	}

	return $total_reads;
}

#######################################################################################
#  total_tag0_perfect_matches_reads - total perfect match read count for tag#0 bam file
#######################################################################################
has 'total_tag0_perfect_matches_reads' => ( isa => 'NpgTrackingNonNegativeInt',
			is => 'ro',
			required   => 0,
			lazy_build  => 1,
                       );
sub _build_total_tag0_perfect_matches_reads {
	my $self = shift;

	my $total_reads = 0;
	my $phix_tag_indices = $self->_run_info_data->{runs_info}->[0]->{phix_tagidx};
	my $pmc = $self->tag0_BamIndexDecoder_metrics->result->perfect_matches_pf_count;
	for my $perfect_matches_tagidx (keys %{$self->tag0_BamIndexDecoder_metrics->result->perfect_matches_pf_count}) {
		next if($phix_tag_indices->{$perfect_matches_tagidx});
		$total_reads += $pmc->{$perfect_matches_tagidx};
	}

	return $total_reads;
}

##################################################################################
# _tag_metrics_results - the results of the tag_metrics qc check for this run/lane
##################################################################################
has '_tag_metrics_results' => (
	isa => 'Object',
	is => 'ro',
	lazy_build => 1,
);
sub _build__tag_metrics_results {
	my $self = shift;

	######################################################################
	# Accessing file system then using the database as a fallback reverses
	# the order used by SeqQC, for example. Will this cause confusion? The
	# reason for using this order is to be sure that a consistent set of
	# data sources is used when a non-Latest_Summary path is specified by
	# the caller
	######################################################################
	my $qcs=npg_qc::autoqc::qc_store->new(use_db => $self->db_lookup);
	my $aqp = $self->archive_qc_path;
	my $c=$qcs->load_from_path($aqp);
	my $tmr=$c->slice(q[class_name], q[tag_metrics]);
	$tmr=$tmr->slice(q[position], $self->position);

	if(!$tmr->results || (@{$tmr->results} == 0)) {
		$c=$qcs->load_run($self->id_run, $self->db_lookup, [ $self->position ]);
		$tmr=$c->slice(q[class_name], q[tag_metrics]);
	}

	return $tmr;
}

###################################################################
# total_pm_lane_reads - total perfect match reads for this run/lane
###################################################################
has 'total_pm_lane_reads' => ( isa => 'NpgTrackingNonNegativeInt',
			is => 'ro',
			required   => 0,
			lazy_build  => 1,
                       );
sub _build_total_pm_lane_reads {
	my $self = shift;

	my $tmr=$self->_tag_metrics_results;

	my $tplr = 0;
	my $pmcr = $tmr->results->[0]->perfect_matches_pf_count;  # this should work for all cases
	for my $k (keys %{$pmcr}) {
		$tplr += $pmcr->{$k};
	}

	return $tplr;
}

##############################################################
# total_lane_reads - from tag_metrics result for this run/lane
##############################################################
has 'total_lane_reads' => ( isa => 'NpgTrackingNonNegativeInt',
			is => 'ro',
			required   => 0,
			lazy_build  => 1,
                       );
sub _build_total_lane_reads {
	my $self = shift;

	my $tmr=$self->_tag_metrics_results;

	my $tlr = 0;
	my $rcr = $tmr->results->[0]->reads_pf_count;  # this should work for all cases
	for my $k (keys %{$rcr}) {
		$tlr += $rcr->{$k};
	}

	return $tlr;
}

###################################################################################################
# barcode_file (default: sanger168.tags, in the NPG repository under tag_sets)
#  This currently detects the 6base or 5base tag set situation and chooses the more appropriate
#   default, but the assumption that everything else will work with the 8base tag set may be overly
#   optimistic.
###################################################################################################
has 'barcode_filename'  => ( isa        => 'NpgTrackingReadableFile',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_barcode_filename {
    my $self = shift;
    my $repos = Moose::Meta::Class->create_anon_class(
        roles => [qw/npg_tracking::data::reference::list/])->new_object()->tag_sets_repository;

	my $min_tag_len = (sort { $a <=> $b } map { length } (values %{$self->_tag_metrics_results->results->[0]->tags}))[0];


	## no critic (ProhibitMagicNumbers)
	if($min_tag_len == 6) {
		return File::Spec->catfile($repos, $BARCODE_6BASES_FILENAME);
	}
	elsif($min_tag_len == 5) {
		return File::Spec->catfile($repos, $BARCODE_5BASES_FILENAME);
	}
	else {
		return File::Spec->catfile($repos, $BARCODE_FILENAME);
	}
	## use critic

    return File::Spec->catfile($repos, $BARCODE_FILENAME);
}

####################################################################
# metrics_output_file (default: <id_run>_<lane>#0_tagfile.metrics
#  in the qc_in directory (usually recalibrated_path for this check)
####################################################################
has 'metrics_output_file'  => ( isa        => 'Str',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_metrics_output_file {
    my $self = shift;

    my $filename = sprintf q[%s/%d_%d#0_tagfile.metrics], $self->cal_path, $self->id_run, $self->position;

    return $filename;
}

#####################################################################
# min_percent_match - threshold for reporting unexpected_tags results
#####################################################################
has 'min_match_percent' => ( isa => 'Num',
                         is => 'ro',
                         default => $MIN_MATCH_PERCENT,
                       );

#####################################################################
# db_lookup (default: 1) - passed to qc_store; determines if database
#  lookup is done or only staging area
#####################################################################
has 'db_lookup' => ( isa => 'Bool',
                     is => 'ro',
                     default => 1,
);

has 'bid_jar_path' => (
        is      => 'ro',
        isa     => 'NpgCommonResolvedPathJarFile',
        coerce  => 1,
        default => $BID_JAR_NAME,
);

has 'run_rows' => (
	isa => 'ArrayRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build_run_rows {
	my ($self) = @_;

	return _fetch_run_rows($self->id_run);
}

#########################################################################################################
# _run_info_data - collates tag information about this and upstream runs. Contains two elements:
#    tag_seq_runs - which of the runs a tag sequence first appears in is determined, and this hash map is
#      set up to map from tag sequences to id_runs
#    runs_info - array whose entries contain tag set information for this and upstream runs
#########################################################################################################
has '_run_info_data' => (
	isa => 'HashRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build__run_info_data {
	my ($self) = @_;

        # fetch initial runs history for intrument from tracking db
        my $run_rows = $self->run_rows;

	my $qcs=npg_qc::autoqc::qc_store->new(use_db => $self->db_lookup);
	my $run_lanes = { (map { $_->[$ID_RUN_POS] => [ $self->position ] } @{$run_rows}) };
	my $c=$qcs->load_lanes($run_lanes, 1, );
	my $rl_tag_metrics=$c->slice(q[class_name], q[tag_metrics]);
	my $rl_tag_metrics_results=$rl_tag_metrics->results;

	my $lane = $self->position;
	my $num_back_runs = $self->num_back_runs;
	my $rid = _additional_run_info($lane, $run_rows, $rl_tag_metrics_results, $num_back_runs);

	return $rid;
}

has 'java_xmx_flag'   => ( is      => 'ro',
                         isa     => 'Str',
                         default => $DEFAULT_JAVA_XMX,
                       );

has 'maskflags_name'   => ( is      => 'ro',
                         isa     => 'NpgCommonResolvedPathExecutable',
                         coerce  => 1,
                         default => 'bammaskflags',
                       );

has 'maskflags_cmd'   => ( is      => 'ro',
                         isa     => 'Str',
                         lazy_build  => 1,
                       );
sub _build_maskflags_cmd {
	my $self = shift;

	return $self->maskflags_name . q[ maskneg=107];
}

## no critic qw(NamingConventions::Capitalization NamingConventions::ProhibitMixedCaseSubs)
has 'BamIndexDecoder_cmd'  => ( isa        => 'Str',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_BamIndexDecoder_cmd {
	my $self = shift;

        my $bid_cmd_template = q[java %s -jar %s COMPRESSION_LEVEL=0 INPUT=%s OUTPUT=/dev/null BARCODE_FILE=%s METRICS_FILE=%s MAX_MISMATCHES=%d MAX_NO_CALLS=%d VALIDATION_STRINGENCY=LENIENT];

        my $bid_cmd = sprintf $bid_cmd_template,
		$self->java_xmx_flag,
		$self->bid_jar_path,
		$self->tag0_bam_file,
		$self->barcode_filename,
		$self->metrics_output_file,
		$self->max_mismatches,
		$self->max_no_calls;

        $bid_cmd .= q[ > /dev/null 2>&1]; # all useful output goes to metrics_file

	return $bid_cmd;
}

##################################################################################
# tag0_BamIndexDecoder_metrics: tag metrics check object - created with the output
#  from a BamIndexDecoder run on the tag#0 bam file
##################################################################################
has 'tag0_BamIndexDecoder_metrics' => (
	isa => 'Object',
	is => 'ro',
	lazy_build => 1,
);
sub _build_tag0_BamIndexDecoder_metrics {
	my ($self) = @_;

	my $bid_cmd = $self->BamIndexDecoder_cmd;

        system($bid_cmd) == 0 or croak qq[Failed to execute BamIndexDecoder command: $bid_cmd];

        #############################################################
        # Read BamIndexDecoder output into a tag_metrics check object
        #  for easier manipulation of values
        #############################################################
        my $tmc=npg_qc::autoqc::checks::tag_metrics->new(id_run => $self->id_run, position => $self->position, input_files => [ $self->metrics_output_file ], path => q{.});
        $tmc->execute;    # parse input_file

        return $tmc;
}
## use critic

#############################################################################################
# _tmc_tag_indexes: maps tag sequences to tag indices for tag set used in BamIndexDecoder run
#############################################################################################
has '_tmc_tag_indexes' => (
	isa => 'HashRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build__tmc_tag_indexes {
	my ($self) = @_;

	return { reverse %{$self->tag0_BamIndexDecoder_metrics->result->tags} };  # tag_seq -> tag_idx map for sanger168 tag set
}

## no critic qw(BuiltinFunctions::ProhibitReverseSortBlock)
#############################################################################################################
# unexpected_tags - tags seen in tag#0 bam file which do not appear in the tag set specified for the run/lane
#############################################################################################################
has 'unexpected_tags' => (
	isa => 'ArrayRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build_unexpected_tags {
	my ($self) = @_;

	my @ret = ();
	my $bid_metrics = $self->tag0_BamIndexDecoder_metrics;
	my $tti = $self->_tmc_tag_indexes;

	my $tag_seq_runs = $self->_run_info_data->{tag_seq_runs};
	for my $tag_seq (sort { $bid_metrics->result->perfect_matches_pf_count->{$tti->{$b}}  <=> $bid_metrics->result->perfect_matches_pf_count->{$tti->{$a}}; } (grep { !/NNNNN/sm && defined $tti->{$_} && $bid_metrics->result->matches_percent->{$tti->{$_}} >= $self->min_match_percent} (values %{$bid_metrics->result->tags}))) {
		my $id_run = ($tag_seq_runs->{$tag_seq}->{id_run}? $tag_seq_runs->{$tag_seq}->{id_run}: q[]);
		my $tag_idx = ($id_run? $tag_seq_runs->{$tag_seq}->{tag_idx}: $tti->{$tag_seq});
		my $pmc = $bid_metrics->result->perfect_matches_pf_count->{$tti->{$tag_seq}};
		my $omm = $bid_metrics->result->one_mismatch_matches_count->{$tti->{$tag_seq}};

		my $entry = { tag_sequence => $tag_seq, id_run => $id_run, tag_index => $tag_idx, perfect_match_count => $pmc, one_mismatch_matches => $omm, };

		push @ret, $entry;
	}

	return \@ret;
}
## use critic

##################################################################################
# prev_runs - runs which were done before this run on the same instrument and slot
##################################################################################
has 'prev_runs' => (
	isa => 'ArrayRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build_prev_runs {
	my ($self) = @_;

	my @ret = ();
	my $run_info_list = $self->_run_info_data->{runs_info};
	my $tag_seq_runs = $self->_run_info_data->{tag_seq_runs};

	for my $i (0..($self->num_back_runs - 1)) {
		my $tti = $self->_tmc_tag_indexes;
		push @ret, _generate_run_info_row($run_info_list->[$i], $self->position, $self->tag0_BamIndexDecoder_metrics, $tti);
	}

	return \@ret;
}

########################################################################################
# you can override the executable name. May be useful for variants like "samtools_irods"
########################################################################################
has 'samtools_name' => (
	is => 'ro',
	isa => 'Str',
	default => $SAMTOOLS_NAME,
);

has 'samtools' => (
	is => 'ro',
	isa => 'NpgCommonResolvedPathExecutable',
	lazy_build => 1,
	coerce => 1,
);
sub _build_samtools {
	my ($self) = @_;
	return $self->samtools_name;
}

override 'can_run' => sub {
	my $self = shift;

	if(defined $self->tag_index) {
		return 0;
	}

	if(!$self->lims->is_pool) {
		return 0;
	}

	return 1;
};

override 'execute' => sub {
	my ($self) = @_;

#	return 1 if super() == 0;

	if(!$self->can_run()) {
		return 1;
	}

	if(! -d $self->in_dir) {
		carp q[Warning: input directory "], $self->in_dir, q[" not found; iRODS, qcdb and possibly Latest_Summary will be used as input sources];
	}

	my $ri = $self->_run_info_data->{runs_info}->[0];
	$self->result->barcode_file($self->barcode_filename);
	$self->result->instrument_name($ri->{instrument_name});
	$self->result->instrument_slot($ri->{slot});
#	$self->result->run_in_progress_date($ri->{status_date});
	$self->result->total_lane_reads($self->total_lane_reads);
	$self->result->perfect_match_lane_reads($self->total_pm_lane_reads);
	$self->result->total_tag0_reads($self->total_tag0_reads);
	$self->result->tag0_perfect_match_reads($self->total_tag0_perfect_matches_reads);
#	$self->result->pass = 1;  # no pass/fail criterion yet, so leave undef

	$self->result->prev_runs($self->prev_runs);

	$self->result->unexpected_tags($self->unexpected_tags);

	return 1;
};

################
# auxiliary subs
################

sub _fetch_run_rows {
	my ($id_run) = @_;

        ###############
        # Connect to db
        ###############
        my $config_file = "$ENV{HOME}/.npg/npg_tracking-Schema";
        my $db_config = Config::Auto::parse($config_file);
        my $dbh;
        eval {
                Readonly::Scalar my $DB_CONNECT_TIMEOUT => 30;
                local $SIG{ALRM} = sub { croak "database connection timed out\n" };
                alarm $DB_CONNECT_TIMEOUT;
                $dbh = DBI->connect($db_config->{live_ro}->{dsn}, $db_config->{live_ro}->{dbuser}) or croak q[Couldn't connect to database: ] . DBI->errstr;
                alarm 0;
        } or croak "Timeout connecting to database $db_config->{live_ro}->{dsn} as user $db_config->{live_ro}->{dbuser}\n";

        ###################
        # Prepare statement
        ###################
	## no critic qw(NamingConventions::ProhibitMixedCaseVars NamingConventions::Capitalization)
        my $getInstrumentRunHistory_sth = $dbh->prepare(
                qq[select
                        r.id_run,
                        rs.date,
                        i.id_instrument,
                        i.name,
                        if(tr.id_tag=22, 'A', IF(tr.id_tag=23, 'B', 'X')) as slot
                from
                        (run r left outer join tag_run tr on r.id_run = tr.id_run and tr.id_tag in (22,23)),
                        instrument i,
                        run_status rs
                where
                        r.id_instrument = i.id_instrument
                        and r.id_run = rs.id_run
                        and rs.id_run_status_dict = 4
                        and i.id_instrument = (select id_instrument from run where id_run = ?)
                        and rs.date <= (select max(date) from run_status where id_run = ? and id_run_status_dict in (2,3,4))
                        and if(tr.id_tag=22, 'A', IF(tr.id_tag=23, 'B', 'X')) = (select if(id_tag=22, 'A', IF(id_tag=23, 'B', 'X')) from (run rx left outer join tag_run trx on rx.id_run = trx.id_run and trx.id_tag in (22,23)) where rx.id_run = ? and (trx.id_tag in (22,23) or trx.id_tag is null))
                order by
                        rs.date desc limit $MAX_RUNS]
        ) or croak q[Couldn't prepare statement: ] . $dbh->errstr;

	## use critic

        ############
        # fetch data
        ############
        $getInstrumentRunHistory_sth->execute($id_run, $id_run, $id_run) or croak $getInstrumentRunHistory_sth->errstr;
        my $rows = $getInstrumentRunHistory_sth->fetchall_arrayref;

        return $rows;
}

######################################################################################################
# _additional_run_info
#       collate tag information for the specified run/lane. Checks which different tags were used in
#       upstream runs. 
######################################################################################################
sub _additional_run_info {
	my ($lane, $run_rows, $tmr_results, $num_back_runs) = @_;

        my %tsr;        # tag sequence runs (where tags are first seen)

        my $downstream_tags;
        $downstream_tags->{master_len} = 0;
        $downstream_tags->{bucket} = [];

        my @ri = ();
        my $num_results = @{$run_rows};
        if($num_results < $num_back_runs) { $num_back_runs = $num_results; }

        for my $i (0..($num_back_runs - 1)) {
		my $run_info = {};

		# Record run-level info
		my $row = $run_rows->[$i];
		my $id_run = $run_info->{id_run} = $row->[$ID_RUN_POS];
		$run_info->{status_date} = $row->[$STATUS_DATE_POS];
		$run_info->{id_instrument} = $row->[$ID_INSTRUMENT_POS];   # ??
		$run_info->{instrument_name} = $row->[$INSTRUMENT_NAME_POS];  # ?? Yes, appears in results
		$run_info->{slot} = $row->[$SLOT_POS];  # ?? Yes, appears in results
		$run_info->{no_tag_metrics_results} = 0;

		# note assumption of unique entry for a given id_run
		my $tmr_run_info = (grep { $_->id_run == $id_run; } (@{$tmr_results}))[0];

		if($tmr_run_info) {
			my $tags_info = $tmr_run_info->tags;

			while(my ($tag_index, $tag_sequence) = each %{$tags_info}) {

				if($tag_index == 0) {  # Ns
					next;
				}

				###################################################################################################
				# save the phix sequence to allow detection of phiX reads when handling data from tag_metrics check
				###################################################################################################
				if($tmr_run_info->spiked_control_index and $tag_index == $tmr_run_info->spiked_control_index) {
					$run_info->{phix_tagidx}->{$tag_index} = 1;
					$run_info->{phix_tagseq}->{$tag_sequence} = 1;
					next;
				}

				my $tag_len = length $tag_sequence;
				$run_info->{lengths}->{$tag_len}++; # allows determination of length of tag in this lane, and a check for inconsistencies
				$run_info->{tags}->{$tag_index}->{tag_sequence} = $tag_sequence;
				$run_info->{tags}->{$tag_index}->{appears_downstream} = 0;

				# if necessary, adjust length of tag for comparison with master run
				my $cmp_tag_seq = $tag_sequence;
				if($downstream_tags->{master_len}) {
					if($tag_len > $downstream_tags->{master_len}) {
						$cmp_tag_seq = substr $tag_sequence, 0, $downstream_tags->{master_len};
					}
				}
				else {
					$downstream_tags->{master_len} = $tag_len;
				}

				# now check to see if the tag appeared in a downstream run
				if(any { /^$cmp_tag_seq/smx } @{$downstream_tags->{bucket}}) {
					$run_info->{tags}->{$tag_index}->{appears_downstream} = 1;
				}
				else {
					push @{$downstream_tags->{bucket}}, $tag_sequence;     # note: actual tag sequence, with unadjusted length
					$tsr{$tag_sequence}->{id_run} = $id_run;
					$tsr{$tag_sequence}->{tag_idx} = $tag_index;
				}
			}
		}
		else {
			$run_info->{no_tag_metrics_results} = 1;
		}

		push @ri, $run_info;
        }

	my $rid;
	$rid->{runs_info} = \@ri;
	$rid->{tag_seq_runs} = \%tsr;

	return $rid;
}

#######################################################################################################
# _generate_run_info_row
#       fetch tag information for run the row. Check on which different tags were used in upstream runs
#######################################################################################################
sub _generate_run_info_row {
         my ($run_info, $lane, $tag_metrics_data, $tti) = @_;

	my $ret = {};

	$ret->{id_run} = $run_info->{id_run};
	$ret->{run_in_progress_date} = $run_info->{status_date};

	if($run_info->{no_tag_metrics_results}) {
		$ret->{is_a_pool} = q[N];
		return $ret;
	}

	my $new_tag_reads = 0;
	my $perfect_matches_total = 0;
	my $ti_count = 0;
	my $appears_downstream_count = 0;
	for my $tag_index (sort keys %{$run_info->{tags}}) {
		$ti_count++;
		if($run_info->{tags}->{$tag_index}->{appears_downstream}) {
			$appears_downstream_count++;
		}
		else {
			my $tag_seq = $run_info->{tags}->{$tag_index}->{tag_sequence};
			my $tag_idx = $tti->{$tag_seq};   # be sure to use the correct tag index for the sequence (from decode set, not from run)
			if(defined $tag_idx) {
				$perfect_matches_total += $tag_metrics_data->result->perfect_matches_pf_count->{$tag_idx};
			}
		}
	}
	$ret->{new_tag_count} = ($ti_count - $appears_downstream_count);
	$ret->{downstream_tag_count} = $appears_downstream_count;
	$ret->{tag_lengths} = [ (sort keys %{$run_info->{lengths}}) ];
	$ret->{perfect_match_reads} = $perfect_matches_total;

	return $ret;
}

####################
# private attributes
####################

no Moose;
__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

npg_qc::autoqc::checks::upstream_tags 

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::upstream_tags;

=head1 DESCRIPTION


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

=head1 AUTHOR

    Kevin Lewis, kl2

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Kevin Lewis

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
