##no critic

=head1 NAME

npg_qc::utils::iRODS 

=head1 SYNOPSIS

use npg_qc::utils::iRODS;

=head1 DESCRIPTION

Wrapper for iRODS (Integrated Rule Oriented Data Systems) icommands.
New sequencing data is written into the NPG iRODS system, and this module
provides a perl-friendly way to query, view, and retrieve those data.

=head1 AUTHOR

Jim Stalker jws@sanger.ac.uk

Kevin Lewis kl2@sanger.ac.uk (adapted for use by vips)

=cut

package npg_qc::utils::iRODS;

use strict;
use warnings;

our $VERSION = '0';

# you need to install your .irodsEnv + .irodsA file on the server side in a
# given path <path1>.  then in your code, you can set up the env variables
# "irodsEnvFile" and "irodsAuthFileName" with the function putenv where you
# give the full path name of the 2 connexion files.  once you have that, please
# note that the "iinit" step is not required anymore. 

my %defaults =
	(
		'irodsEnvFile'      => '~/.irods/.irodsEnv',
###		'irodsAuthFileName' => '/lustre/scratch102/conf/irodsA',
		'default_dest' => '/tmp',
		'ignore_errors' => 0,
	);


=head2 new

    Args [...]    : key/value pairs allowing specific settings of instance variables. Currently these are:
			'irodsEnvFile' - the iRODS environment file [default: '~/.irods/.irodsEnv']
			'default_dest' - where iget will put files [default: '/tmp']
			'ignore_errors' - if non-zero, errors from ils commands will be ignored [[default: 0]
    Example    : my $irods = vips::iRODS->new('irodsEnvFile'=>'~/.irods/.irodsEnv');
    Returntype : vips::iRODS object

=cut

sub new {
	my ($class, @args) = @_;
	my $self = { %defaults, @args };
	bless($self,$class);
	# set up iRODS environment?

	return $self;
}

=head2 ipwd

    Returns current iRODS "working directory"
    Args [0]    : None
    Example    : my $pwd = $irods->ipwd;
    Returntype : String

=cut

sub ipwd {
    my ($self) = @_;
    my $cmd = 'ipwd';
    my $out = `$cmd`;

	chomp $out;

    return $out;
}

=head2 ils

    List file(s)
    Arg [...]    : optional directories or file names
    Example    : my @a = $irods->ils('/seq/5600', '/seq/620/620_1.bam');
    Returntype : array ref

=cut

sub ils {
	my ($self, @targets) = @_;
	my $cmd = 'ils';
	my @ret;
	my @errvec = ();

	$cmd = join(' ', ($cmd, @targets)) if(@targets);

	open my $data, "$cmd 2>&1 |" or return [ "Error processing $cmd" ];
	my @a = <$data>;
	close $data;

	chomp @a;
	@a = map { s/^\s*//; s/\s*$//; $_; } @a;
	my $dir = '';
	for my $item (@a) {
		if($item =~ /^ERROR:/) {
			push @errvec, $item;
		}
		elsif($item =~ /^(.*):$/) {	# directory name
			$dir = $1 . '/';
		}
		else {
			if($item =~ /^\//) {	# file name already fully-qualified?
				$dir = '';
			}
			push @ret, "${dir}${item}";
		}
	}

	die (@errvec) if(!$self->{ignore_errors} and @errvec);

	return \@ret;
}

=head2 ils_wildcard

    List file(s) - either the "file_name" or (optional) "collection" parameters may contain
	SQL-style wildcards. If "collection" is unspecified, the value specified by ipwd will
	be used.
    Arg [2]    : filename, [collection]
    Example    : my @a = $irods->ils_wildcard('5630_%.ba%', '/seq/5630');
    Returntype : array ref

=cut

sub ils_wildcard {
	my ($self, $file_pat, $coll_pat) = @_;
	my @errvec = ();

	die "No file pattern specified" unless($file_pat);

	if(!$coll_pat) { $coll_pat = $self->ipwd };

	my $cmd = qq(iquest "%s/%s" "select COLL_NAME, DATA_NAME where COLL_NAME like '$coll_pat' and DATA_NAME like '$file_pat'");

	open my $data, "$cmd 2>&1 |" or return [ "Error processing $cmd" ];
	my @ret = <$data>;
	close $data;

	chomp @ret;
	@errvec = grep { /^ERROR: / } @ret;
	die (@errvec) if(!$self->{ignore_errors} and @errvec);

	return \@ret;
}

=head2 find_files_by_run_lane

    List file(s) - return the filename(s) specified by "run", (optionally) "lane and "tag_index"
                   only looks for sequence files (e.g. bams) and only the ones we want downstream
                   e.g. _phix or _human not included
    Args [3]    : run, lane, [tag_index]
    Example    : my @a = $irods->find_files_by_run_lane('5630_%.ba%', '/seq/5630');
    Returntype : array ref

=cut

sub find_files_by_run_lane {
    my ($self, $run, $lane, $tag_index) = @_;
    unless ($run){
         $self->throw("Missing parameter: run.\n");
    }
    my $cmd = "imeta -z seq qu -d id_run = $run";
	$cmd .= " and lane = $lane" if ($lane);
	$cmd .= " and tag_index = $tag_index" if ($tag_index);

    $cmd .= " and target = 1 "; ## 20/04/11 force choice to only the downstream files !

    open(my $irods, "$cmd |");

    my @out;
    my $path = '';
    while (<$irods>) {
        # output looks like:
        #collection: /seq/5253
        #dataObj: 5253_1.bam
        #----
        #collection: /seq/5253
        #dataObj: 5253_2.bam
        # or
        # No rows found

        if (/^collection: (.+)$/){
            $path = $1;
        }
        if (/^dataObj: (.+)$/){
            push @out, "$path/$1";
        }
    }
    close $irods;
    return \@out;
}

=head2 get_file_md5

    List file(s) - return the md5 checksum for the specified file
    Args [1]    : filename
    Example    : my $md5 = $irods->get_file_md5('/seq/5630/5600_8.bam');
    Returntype : string

=cut

sub get_file_md5 {
    my ($self, $file) = @_;
    my $cmd = "ichksum $file";

    my @md5 = `$cmd`;
    chomp @md5;
    $md5[0] =~s/.*\s//;
    return $md5[0];
}


=head2 get_file_size

    List file(s) - return the size of the specified file
    Args [1]    : filename
    Example    : my $size = $irods->get_file_size('/seq/5630/5600_8.bam');
    Returntype : number

=cut

sub get_file_size {
    my ($self, $file) = @_;
    my $cmd = "ils -l $file";

    open(my $irods, "$cmd |");
    my $line = <$irods>;
    #   srpipe            0 res-g2                17084186273 2010-10-20.19:13 & 5330_1.bam
    my @fields = split ' ', $line;
    return $fields[3];
}

=head2 get_file

    List file(s) - fetch the specified file (to the optionally-specfied destination)
    Args [2]    : filename [, destination]
    Example    : my $size = $irods->get_file('/seq/5630/5600_8.bam', '~/bam_files');
    Returntype : exit status of iget command

=cut

sub get_file {
    
    my ($self, $file, $dest) = @_;
    
    $dest ||= $self->{default_dest};
    
    die "Destination doesn't exist or is not directory: $dest" unless(-d $dest);
    die "Destination not writeable: $dest" unless(-w $dest);
    
    my $cmd = "iget";
    my @args = ($cmd, "-K", "-f", $file, $dest);
    ##my @args = ($cmd, "-K", "-Q", "-f", $file, $dest);

    return system(@args);
}


=head2 get_imeta_for_file

    Args [1]   : filename
    Example    : my $atts = $irods->get_imeta_for_file('/seq/5630/5600_8.bam');
    Returntype : ref to hash

=cut

sub get_imeta_for_file{

    my($self,$file) = @_;

    my $cmd = "imeta ls -d $file";


    my($at,$va,$un,);
    my $atts = {};

    if(open(my $irods, "$cmd |")){
	while(<$irods>){
	    if(/attribute\:\s+(\S+)/){
		$at = $1;
	    }
	    if(/value\:\s+(\S+)/){
		$va = $1;
	    }
	    if(/units\:\s+(\S+)/){
		$un = $1;
	    }
	    if(/^----/ && $at =~ /\S/){
		$atts->{$at}->{'value'} = $va;
		$atts->{$at}->{'units'} = $un if defined $un && $un =~ /\S/;
		($at,$va,$un) = ('','','');
	    }
	}
	close $irods;
    }else{
	die "cant run $cmd\n";
    }

    if($at =~ /\S/){
	$atts->{$at}->{'value'} = $va;
	$atts->{$at}->{'units'} = $un if defined $un && $un =~ /\S/;
    }

    return($atts);

}

1;
