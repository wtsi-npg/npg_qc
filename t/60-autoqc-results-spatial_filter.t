use strict;
use warnings;
use Test::More tests => 27;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use Carp;
use JSON;

use_ok ('npg_qc::autoqc::results::spatial_filter');

my $tempdir = tempdir( CLEANUP => 1);
{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 1,
                                       id_run   => 25810,
                                 );
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    my $stats_output_string = slurp 't/data/autoqc/25810_1.bam.filter.stats';

    $r->parse_output(\$stats_output_string);    

    is($r->num_total_reads, 629464762, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 42, 'spatial filter fail reads');    

    lives_ok {
      $r->freeze();
      $r->store(qq{$tempdir/spatial_filter_1.json});
    } 'no error when save data into json';

    is ($r->composition->num_components, 1, 'one component');
    my $component = $r->composition->get_component(0);
    is ($component->id_run, 25810, 'component id_run');
    is ($component->position, 1, 'component position');
    ok (!$component->has_tag_index, 'component tag index has not been set');
    is ($component->tag_index, undef, 'component tag index is undefined');
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 2,
                                       id_run   => 25810,
                                 );

    open my $stats_output_fh, '<',
      't/data/autoqc/25810_2.bam.filter.stats' or croak 'fail to open fh';
    lives_ok {
      local *STDIN=$stats_output_fh;
      $r->parse_output();
    } 'parse from (pseudo) stdin';
    close $stats_output_fh or croak 'fail to close fh';    

    is($r->num_total_reads, 649612652, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 1024, 'spatial filter fail reads');    
    
    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no error when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/25810_2.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 649612652,
      'num_spatial_filter_fail_reads' => 1024,
      'id_run' => 25810,
      'info' => {},
      'position' => 2,
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{'__CLASS__'};
    delete $hash->{'composition'};
    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 3,
                                       id_run   => 8926,
                                 );
    lives_ok {
      my$s='';
      $r->parse_output(\$s);
    } 'parse from empty string';

    is($r->num_total_reads, undef, 'total reads');
    is($r->num_spatial_filter_fail_reads, undef, 'spatial filter fail reads');
    my $dest = $tempdir . '/some.json';
    lives_ok {$r->store($dest)} 'save data into json';
    ok (-e $dest, 'file created');
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 4,
                                       id_run   => 25810,
                                 );
    open my $stats_output_fh, '<',
      't/data/autoqc/25810_4.bam.filter.stats' or croak 'fail to open fh';

    lives_ok {
      local *STDIN=$stats_output_fh;
      $r->parse_output();
    } 'parse from (pseudo) stdin';
    close $stats_output_fh or croak 'fail to close fh';

    is($r->num_total_reads, 653495042, 'total reads');
    is($r->num_spatial_filter_fail_reads, 115390, 'spatial filter fail reads');

    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no error when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/25810_4.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 653495042,
      'num_spatial_filter_fail_reads' => 115390,
      'id_run' => 25810,
      'info' => {},
      'position' => 4,
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{'__CLASS__'};
    delete $hash->{'composition'};
    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}

1;
