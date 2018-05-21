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
                                       id_run   => 25830,
                                 );
    isa_ok ($r, 'npg_qc::autoqc::results::spatial_filter');

    $r->parse_output(['t/data/autoqc/25830_1#1.filter.stats']);

    is($r->num_total_reads, 382658, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 32768, 'spatial filter fail reads');    

    lives_ok {
      $r->freeze();
      $r->store(qq{$tempdir/spatial_filter_1.json});
    } 'no error when save data into json';

    is ($r->composition->num_components, 1, 'one component');
    my $component = $r->composition->get_component(0);
    is ($component->id_run, 25830, 'component id_run');
    is ($component->position, 1, 'component position');
    ok (!$component->has_tag_index, 'component tag index has not been set');
    is ($component->tag_index, undef, 'component tag index is undefined');
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 1,
                                       id_run   => 25830,
                                 );

    my $stats_output_file = q{t/data/autoqc/25830_1#2.filter.stats};
    lives_ok {
      $r->parse_output([$stats_output_file]);
    } 'parse from file';

    is($r->num_total_reads, 306160, 'total reads');    
    is($r->num_spatial_filter_fail_reads, 0, 'spatial filter fail reads');    
    
    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no error when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/25830_1.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 306160,
      'num_spatial_filter_fail_reads' => 0,
      'id_run' => 25830,
      'info' => {},
      'position' => 1,
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
    my $empty_stats_file = q{t/data/autoqc/spatial_filter/empty.stats};
    lives_ok {
      $r->parse_output([$empty_stats_file]);
    } 'parse from empty file';

    is($r->num_total_reads, undef, 'total reads');
    is($r->num_spatial_filter_fail_reads, undef, 'spatial filter fail reads');
    my $dest = $tempdir . '/some.json';
    lives_ok {$r->store($dest)} 'save data into json';
    ok (-e $dest, 'file created');
}

{
    my $r = npg_qc::autoqc::results::spatial_filter->new(
                                       position => 1,
                                       id_run   => 25830,
                                 );
    my $stats_output_file = q{t/data/autoqc/25830_1#3.filter.stats};
    lives_ok {
      $r->parse_output([$stats_output_file]);
    } 'parse from (pseudo) stdin';

    is($r->num_total_reads, 54332, 'total reads');
    is($r->num_spatial_filter_fail_reads, 42, 'spatial filter fail reads');

    lives_ok {
      $r->freeze();
      $r->store($tempdir);
    } 'no error when save data into json (store passed directory)';

    my $hash = from_json( slurp qq{$tempdir/25830_1.spatial_filter.json} );

    my $expected_hash_structure = {
      'num_total_reads' => 54332,
      'num_spatial_filter_fail_reads' => 42,
      'id_run' => 25830,
      'info' => {},
      'position' => 1,
    };

    ok( exists $hash->{__CLASS__}, q{__CLASS__ key found} );
    delete $hash->{'__CLASS__'};
    delete $hash->{'composition'};
    is_deeply( $hash, $expected_hash_structure, q{expected results obtained} );
}

1;
