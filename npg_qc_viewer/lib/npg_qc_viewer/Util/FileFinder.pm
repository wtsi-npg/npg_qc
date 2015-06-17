package npg_qc_viewer::Util::FileFinder;
use Moose;
use Carp;
use English qw{-no_match_vars};
use File::Spec::Functions qw(catfile);
use File::Basename;
use Readonly;
use npg_qc::Schema;

with qw/ npg_tracking::glossary::lane
  npg_tracking::glossary::tag
  npg_tracking::illumina::run::short_info
  npg_tracking::illumina::run::folder
  /;

our $VERSION = '0';
Readonly::Scalar our $FILE_EXTENSION    => q[fastq];
Readonly::Scalar our $RESULT_CLASS_NAME => q[Fastqcheck];

has 'db_lookup'                         => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  writer   => '_set_db_lookup',
  default  => 1,
);

has 'file_extension' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
  default  => $FILE_EXTENSION,
);

has 'with_t_file' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  default  => 0,
);

has 'lane_archive_lookup' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  default  => 1,
);

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

sub _build_qc_schema {
  my $self   = shift;
  my $schema = npg_qc::Schema->connect();
  return $schema;
}

has 'globbed' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

sub _build_globbed {
  my $self   = shift;
  my $hfiles = {};

  if ( $self->file_extension eq q[fastqcheck] && $self->db_lookup ) {
    my $pattern = join q[_], $self->id_run, $self->position;
    $pattern .= q[%];

    if ( $self->file_extension ) {
      $pattern .= $self->file_extension;
    }
    my @rows = $self->qc_schema->resultset($RESULT_CLASS_NAME)->search( 
      { id_run => $self->id_run, position => $self->position, },
      { columns   => 'file_name', },
    )->all;
    foreach my $row (@rows) {
      my $fname = $row->file_name;
      $hfiles->{$fname} = $fname;
    }
  }
  
  if ( ( scalar keys %{$hfiles} ) == 0 ) {
    my $path =
      ( defined $self->tag_index && $self->lane_archive_lookup )
      ? File::Spec->catfile( $self->archive_path, $self->lane_archive )
      : $self->archive_path;
      
    my $glob = catfile( $path, q[*] );
    
    if ( $self->file_extension ) {
      $glob .= $self->file_extension;
    }
    
    my @files = glob "$glob";
    foreach my $file (@files) {
      my ( $fname, $dir, $ext ) = fileparse($file);
      $hfiles->{$fname} = $file;
    }
    
    $self->_set_db_lookup(0);
  }
  return $hfiles;
}

sub BUILD {
  my $self = shift;
  $self->_test_options_compatibility();
  return;
}

sub _test_options_compatibility {
  my $self = shift;
  if ( defined $self->tag_index && $self->with_t_file ) {
    croak 'tag_index and with_t_file attributes cannot be both set';
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;


