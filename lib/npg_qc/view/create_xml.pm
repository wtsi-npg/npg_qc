#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-16
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::view::create_xml;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp qw(confess cluck carp croak);
use Readonly;

use npg_qc::model::create_xml;
use npg_qc::model::chip_summary;
use npg_qc::model::cumulative_errors_by_cycle;
use npg_qc::model::errors_by_cycle;
use npg_qc::model::errors_by_cycle_and_nucleotide;
use npg_qc::model::errors_by_nucleotide;
use npg_qc::model::error_rate_reference_including_blanks;
use npg_qc::model::error_rate_reference_no_blanks;
use npg_qc::model::error_rate_relative_reference_cycle_nucleotide;
use npg_qc::model::error_rate_relative_sequence_base;
use npg_qc::model::information_content_by_cycle;
use npg_qc::model::lane_qc;
use npg_qc::model::log_likelihood;
use npg_qc::model::most_common_blank_pattern;
use npg_qc::model::most_common_word;
use npg_qc::model::run_config;
use npg_qc::model::run_tile;
use npg_qc::model::signal_mean;
use npg_qc::model::tile_score;
use npg_qc::model::move_z;
use npg_qc::model::runlog_sax_handler_simple;
use XML::SAX::ParserFactory;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

Readonly our $THREE => 3;

sub decor {
  my $self   = shift;

  return 0;
}

sub content_type {
  my $self   = shift;

  return 'application/xml';
}

sub render {
  my ($self, @args) = @_;

  return $self->create();
}

sub create {
  my ($self)  = @_;

  my $util    = $self->util();
  my $cgi     = $util->cgi();

  my $content = $cgi->param('POSTDATA');

  if (!$content) {
    $content = $cgi->param('XForms:Model');
  }

  my $parsed_xml = $self->parse_xml($content);

  if (ref$parsed_xml eq 'HASH') {
    return $self->run_config($parsed_xml);
  }

  my $dataset = $parsed_xml->getElementsByTagName('dataset');
  $dataset = lc$dataset;

  eval {
    $self->allowed_datasets($dataset);
  } or do {
    croak $EVAL_ERROR
  };

  if($dataset eq 'z_log'){
    undef $parsed_xml;
    return $self->z_log($content);
  }

  return $self->$dataset($parsed_xml);

}

sub allowed_datasets {
  my ($self, $dataset) = @_;

  my $allowed_datasets = {
    z_log        => 1,
    run_config   => 1,
    summary_data => 1,
    signal_mean  => 1,
    tile_all     => 1,
    tile_score   => 1,
    swiftreport  => 1,
  };

  if (!$allowed_datasets->{$dataset}) {
    croak 'This dataset is not allowed to be stored';
  }

  return 1;
}

sub parse_xml {
  my ($self, $content) = @_;

  my $util   = $self->util();
  my $parser = $util->parser();

  my $parsed_xml;

  eval {

    $parsed_xml = $parser->parse_string($content);
    1;

  } or do {

    $content =~ s/[<][?]xml[ ]version=["]1[.]0["][ ]encoding=["]utf-8["][?][>]//gxms;

    if ($content =~ /\<dataset\>run_config\<\/dataset\>/xms) {
      my ($id_run) = $content =~ /id_run=\"(\d+)\"/xms;
      my ($config_text) = $content =~ /config_text=\"(.*)\"\ \/>/xms;
      $parsed_xml = {
        dataset      => 'run_config',
        attributes => {
          id_run      => $id_run,
          config_text => $config_text,
        },
      };

    } else {

      carp 'No content';
      croak 'No content';

    }

  };

  return $parsed_xml;
}

sub response_object {
  my ($self, $dataset) = @_;

  return qq{<?xml version="1.0" encoding="utf-8"?><sent_type>$dataset</sent_type>};
}

sub get_run_tile {
  my ($self, $arg_refs) = @_;
  my $util = $self->util();

  if (!$arg_refs->{id_run}) {
    my $run_tile = $arg_refs->{parsed_xml};
    $arg_refs->{id_run}   = $run_tile->getAttribute('id_run');
    $arg_refs->{tile}     = $run_tile->getAttribute('tile');
    $arg_refs->{position} = $run_tile->getAttribute('position');
    $arg_refs->{end}      = $run_tile->getAttribute('end') || 1;
  }

  my $run_tile_object = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => $arg_refs->{id_run},
    tile     => $arg_refs->{tile},
    position => $arg_refs->{position},
    end      => $arg_refs->{end},
  });

  if ($run_tile_object->id_run_tile()) {
    $run_tile_object->read();
  };

  if (!$run_tile_object->id_run_tile() || ((! defined $run_tile_object->row()) && (defined $arg_refs->{row}))) {

    if (! defined $arg_refs->{row}) { $arg_refs->{row} = undef; };
    if (! defined $arg_refs->{col}) { $arg_refs->{col} = undef; };
    if (! defined $arg_refs->{avg_newz}) { $arg_refs->{avg_newz} = undef; };
    $run_tile_object->row($arg_refs->{row});
    $run_tile_object->col($arg_refs->{col});
    $run_tile_object->avg_newz($arg_refs->{avg_newz});

    $run_tile_object->save();

  };

  return $run_tile_object;
}

sub z_log {
  my ($self, $content) = @_;
  my $util = $self->util();

  #set up which SAX parser to be used, the default is XML::SAX::PurePerl(slow)
  $XML::SAX::ParserPackage = 'XML::SAX::ExpatXS'; ## no critic(Variables::ProhibitPackageVars)
  #warn "creating a handler\n";
  #create a handler
  my $handler = npg_qc::model::runlog_sax_handler_simple->new({util =>$util });
  #create a parser using ParserFactory
  #warn "creating a SAX factory\n";
  my $parser = XML::SAX::ParserFactory->parser(Handler => $handler);
  #warn "parsing the content\n";

  $util->transactions(0);
  eval {
    $parser->parse_string($content);
    warn "finish parsing xml\n";
    $util->dbh->commit();
    warn "finish commit \n";
    $util->transactions(1);
    1;
  } or do {
    $util->transactions(1);
    $util->dbh->rollback();
    croak $EVAL_ERROR;
  };

  return $self->response_object('z_log');
}
sub z_log_libxml {
  #warn "in z_log\n\n";
  my ($self, $parsed_xml) = @_;
  my $tiles = $parsed_xml->getElementsByTagName('tile');

  foreach my $tile (@{$tiles}) {

    my $arg_refs = {
      id_run   => $tile->getAttribute('id_run'),
      tile     => $tile->getAttribute('tile'),
      position => $tile->getAttribute('position'),
      end      => $tile->getAttribute('end'),
      row      => $tile->getAttribute('row'),
      col      => $tile->getAttribute('col'),
      avg_newz => $tile->getAttribute('avg_newz'),
    };

    my $run_tile = $self->get_run_tile($arg_refs);
    my $move_z_list = $tile->getElementsByTagName('move_z');

    foreach my $move_z (@{$move_z_list}) {

      my $move_z_object = npg_qc::model::move_z->new({
        util        => $self->util(),
        id_run_tile => $run_tile->id_run_tile(),
        cycle       => $move_z->getAttribute('cycle'),
        currentz    => $move_z->getAttribute('currentz'),
        targetz     => $move_z->getAttribute('targetz'),
        newz        => $move_z->getAttribute('newz'),
        start       => $move_z->getAttribute('start'),
        stop        => $move_z->getAttribute('stop'),
        move        => $move_z->getAttribute('move'),
      });

      eval { $move_z_object->save(); } or do { confess $EVAL_ERROR; };
    }
  }
  return $self->response_object('z_log');
}

sub summary_data {
  my ($self, $parsed_xml) = @_;

  my $run = $parsed_xml->getElementsByTagName('run')->shift();
  my $id_run = $run->getAttribute('id_run');
  my $paired = $run->getAttribute('paired');
  my $util = $self->util();

  my $chip_summary = $parsed_xml->getElementsByTagName('chip_summary')->shift();

  if ($chip_summary) {

    my $row = $chip_summary->getElementsByTagName('row')->shift();

    my $chip_summary_obj = npg_qc::model::chip_summary->new({
      util   => $util,
      id_run => $id_run,
      paired => $paired,
    });

    my @fields = $chip_summary_obj->fields();
    splice @fields, 0, $THREE;

    foreach my $f (@fields) {
      $chip_summary_obj->{$f} = $row->getAttribute($f);
    }

    $chip_summary_obj->save();

  }

  my $lane_qc = $parsed_xml->getElementsByTagName('lane_info')->shift();

  my @rows = $lane_qc->getElementsByTagName('row');

  my $lane_qc_model = npg_qc::model::lane_qc->new({
      util        => $util,
    });

  my @fields = $lane_qc_model->fields();
  splice @fields, 0, 2;

  my $tr_state  = $util->transactions();

  my $dbh       = $util->dbh();
  $util->transactions(0);

  eval {

    foreach my $row (@rows) {

      my $lane = $row->getAttribute('lane');
      my $tile = $row->getAttribute('tile');
      my $end  = $row->getAttribute('end');

      $tile =~ s/\A0*//gxms;

      my $arg_refs = {
        parsed_xml => $parsed_xml,
        id_run     => $id_run,
        tile       => $tile,
        position   => $lane,
        end        => $end,
      };

      my $run_tile = $self->get_run_tile($arg_refs);

      my $lane_qc_obj = npg_qc::model::lane_qc->new({
        util        => $util,
        id_run_tile => $run_tile->id_run_tile(),
      });

      foreach my $f (@fields) {
        my $attribute_value = $row->getAttribute($f);
        if($attribute_value eq 'unknown'){
          $attribute_value = undef;
        }
        $lane_qc_obj->{$f} = $attribute_value;
      }
      eval {
        $lane_qc_obj->save();
        1;
      } or do {
        croak qq{Lane QC - $id_run:$lane:$tile:$end - $EVAL_ERROR};
      };

    }
    1;

  } or do {

    $self->util->transactions($tr_state);

    $tr_state and $dbh->rollback();

    croak $EVAL_ERROR . q[Failed to save summary_data];
  };

  $util->transactions($tr_state);

  eval {

    $tr_state and $dbh->commit();
    1;

  } or do {

    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q[Failed to save summary_data];

  };

  return $self->response_object('summary_data');
}

sub run_config {
  my ($self, $parsed_xml) = @_;
  my ($id_run, $config_text);

  if (ref$parsed_xml eq 'HASH') {
    $id_run      = $parsed_xml->{attributes}->{id_run};
    $config_text = $parsed_xml->{attributes}->{config_text};
  } else {
    my $row = $parsed_xml->getElementsByTagName('run_config')->shift();
    $id_run      = $row->getAttribute('id_run');
    $config_text = $row->getAttribute('config_text');
  }

  my $run_config = npg_qc::model::run_config->new({
    util        => $self->util(),
    id_run      => $id_run,
    config_text => $config_text,
  });

  $run_config->save();

  return $self->response_object('run_config');
}

sub signal_mean {
  my ($self, $parsed_xml) = @_;

  my $run = $parsed_xml->getElementsByTagName('run')->shift();

  my $id_run = $run->getAttribute('id_run');

  my $lanes_node = $run->getElementsByTagName('lanes')->shift();

  my @lanes = $lanes_node->getElementsByTagName('lane');

  foreach my $lane (@lanes) {
    my $position = $lane->getAttribute('position');
    my $signal_means = $lane->getElementsByTagName('signal_means')->shift();
    my @rows = $signal_means->getElementsByTagName('row');
    foreach my $row (@rows) {

      my $signal_mean = npg_qc::model::signal_mean->new({
        util     => $self->util(),
        id_run   => $id_run,
        position => $position,
        cycle    => $row->getAttribute('cycle'),
      });

      my @fields = $signal_mean->fields();
      splice @fields, 0, $THREE;

      foreach my $f (@fields) {
        $signal_mean->{$f} = $row->getAttribute($f);
      }

      $signal_mean->save();

    }

  }

  return $self->response_object('signal_mean');
}

sub tile_all {
  my ($self, $parsed_xml) = @_;

  my $run_tiles = $parsed_xml->getElementsByTagName('run_tile');

  foreach my $tile (@{$run_tiles}) {

    my $arg_refs = { parsed_xml => $tile };

    my $run_tile = $self->get_run_tile($arg_refs);

    my $tile_all = $parsed_xml->getElementsByTagName('tile_all')->shift();

    my @rows = $tile_all->getElementsByTagName('row');

    foreach my $row (@rows) {

      my $tile_all_obj = npg_qc::model::tile_all->new({
        util => $self->util(),
        id_run_tile => $run_tile->id_run_tile(),
        cycle       => $row->getAttribute('cycle'),
      });

      my @fields = $tile_all_obj->fields();
      splice @fields, 0, 2;

      foreach my $f (@fields) {
        $tile_all_obj->{$f} = $row->getAttribute($f);
      }

      $tile_all_obj->save();

    }

  }

  return $self->response_object('tile_all');
}

sub tile_score {
  my ($self, $parsed_xml) = @_;

  my $util = $self->util();

  my $run_tiles = $parsed_xml->getElementsByTagName('run_tile');

  foreach my $tile (@{$run_tiles}) {

  my $dbh       = $util->dbh();
  my $tr_state  = $util->transactions();
  $util->transactions(0);

  eval {
    my $arg_refs = { parsed_xml => $tile };

    my $run_tile = $self->get_run_tile($arg_refs);

    my $tile_score = $tile->getElementsByTagName('tile_score')->shift();
    $self->table_tile_score($tile_score, $run_tile);

    my $cumulative_errors_by_cycle = $tile->getElementsByTagName('cumulative_errors_by_cycle')->shift();
    $self->table_cumulative_errors_by_cycle($cumulative_errors_by_cycle, $run_tile);

    my $log_likelihood = $tile->getElementsByTagName('log_likelihood')->shift();
    $self->table_log_likelihood($log_likelihood, $run_tile);

    my $information_content_by_cycle = $tile->getElementsByTagName('information_content_by_cycle')->shift();
    $self->table_information_content_by_cycle($information_content_by_cycle, $run_tile);

    my $error_rate_relative_reference_cycle_nucleotide = $tile->getElementsByTagName('error_rate_relative_reference_cycle_nucleotide')->shift();
    $self->table_error_rate_relative_reference_cycle_nucleotide($error_rate_relative_reference_cycle_nucleotide, $run_tile);

    my $errors_by_cycle = $tile->getElementsByTagName('errors_by_cycle')->shift();
    $self->table_errors_by_cycle($errors_by_cycle, $run_tile);

    my $error_rate_reference_including_blanks = $tile->getElementsByTagName('error_rate_reference_including_blanks')->shift();
    $self->table_error_rate_reference_including_blanks($error_rate_reference_including_blanks, $run_tile);

    my $error_rate_reference_no_blanks = $tile->getElementsByTagName('error_rate_reference_no_blanks')->shift();
    $self->table_error_rate_reference_no_blanks($error_rate_reference_no_blanks, $run_tile);

    my $error_rate_relative_sequence_base = $tile->getElementsByTagName('error_rate_relative_sequence_base')->shift();
    $self->table_error_rate_relative_sequence_base($error_rate_relative_sequence_base, $run_tile);

    my $errors_by_nucleotide = $tile->getElementsByTagName('errors_by_nucleotide')->shift();
    $self->table_errors_by_nucleotide($errors_by_nucleotide, $run_tile);

    my $errors_by_cycle_and_nucleotide = $tile->getElementsByTagName('errors_by_cycle_and_nucleotide')->shift();
    $self->table_errors_by_cycle_and_nucleotide($errors_by_cycle_and_nucleotide, $run_tile);

    my $most_common_word = $tile->getElementsByTagName('most_common_word')->shift();
    $self->table_most_common_word($most_common_word, $run_tile);

    my $most_common_blank_pattern = $tile->getElementsByTagName('most_common_blank_pattern')->shift();
    $self->table_most_common_blank_pattern($most_common_blank_pattern, $run_tile);
    1;

  } or do {

    $self->util->transactions($tr_state);

    $tr_state and $dbh->rollback();

    croak $EVAL_ERROR . q[Failed to save tile_score];
  };

  $util->transactions($tr_state);

  eval {

    $tr_state and $dbh->commit();
    1;

  } or do {

    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q[Failed to save tile_score];

  };

  }

  return $self->response_object('tile_score');
}

sub table_most_common_blank_pattern {
  my ($self, $most_common_blank_pattern, $run_tile) = @_;

  my $mcbp_object = npg_qc::model::most_common_blank_pattern->new({
    util        => $self->util(),
  });

  my @fields = $mcbp_object->fields();
  splice @fields, 0, 2;

  my @rows = $most_common_blank_pattern->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $mcbp = npg_qc::model::most_common_blank_pattern->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
    });

    foreach my $f (@fields) {
      $mcbp->{$f} = $row->getAttribute($f);
    }

    $mcbp->save();

  }

  return;
}

sub table_most_common_word {
  my ($self, $most_common_word, $run_tile) = @_;

  my $mcw_object = npg_qc::model::most_common_word->new({
    util        => $self->util(),
  });

  my @fields = $mcw_object->fields();
  splice @fields, 0, 2;

  my @rows = $most_common_word->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $mcw = npg_qc::model::most_common_word->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
    });

    foreach my $f (@fields) {
      $mcw->{$f} = $row->getAttribute($f);
    }

    $mcw->save();

  }

  return;
}

sub table_errors_by_cycle_and_nucleotide {
  my ($self, $errors_by_cycle_and_nucleotide, $run_tile) = @_;

  my $ebcan_object = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util        => $self->util(),
  });

  my @fields = $ebcan_object->fields();
  splice @fields, 0, 2;

  my @rows = $errors_by_cycle_and_nucleotide->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $ebcan = npg_qc::model::errors_by_cycle_and_nucleotide->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
      read_as     => $row->getAttribute('read_as')
    });

    foreach my $f (@fields) {
      $ebcan->{$f} = $row->getAttribute($f);
    }

    $ebcan->save();

  }

  return;
}

sub table_errors_by_nucleotide {
  my ($self, $errors_by_nucleotide, $run_tile) = @_;

  my $ebn_object = npg_qc::model::errors_by_nucleotide->new({
    util        => $self->util(),
  });

  my @fields = $ebn_object->fields();

  splice @fields, 0, 2;

  my @rows = $errors_by_nucleotide->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $ebn = npg_qc::model::errors_by_nucleotide->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      read_as     => $row->getAttribute('read_as'),
    });

    foreach my $f (@fields) {
      $ebn->{$f} = $row->getAttribute($f);
    }

    $ebn->save();

  }

  return;
}

sub table_error_rate_relative_sequence_base {
  my ($self, $error_rate_relative_sequence_base, $run_tile) = @_;

  my $errsb_object = npg_qc::model::error_rate_relative_sequence_base->new({
    util        => $self->util(),
  });

  my @fields = $errsb_object->fields();
  splice @fields, 0, 2;

  my @rows = $error_rate_relative_sequence_base->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $errsb = npg_qc::model::error_rate_relative_sequence_base->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      read_as     => $row->getAttribute('read_as'),
    });

    foreach my $f (@fields) {
      $errsb->{$f} = $row->getAttribute($f);
    }

    $errsb->save();

  }

  return;
}

sub table_error_rate_reference_no_blanks {
  my ($self, $error_rate_reference_no_blanks, $run_tile) = @_;

  my $errnb_object = npg_qc::model::error_rate_reference_no_blanks->new({
    util        => $self->util(),
  });

  my @fields = $errnb_object->fields();
  splice @fields, 0, 2;

  my @rows = $error_rate_reference_no_blanks->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $errnb = npg_qc::model::error_rate_reference_no_blanks->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      really       => $row->getAttribute('really'),
    });

    foreach my $f (@fields) {
      $errnb->{$f} = $row->getAttribute($f);
    }

    $errnb->save();

  }

  return;
}

sub table_error_rate_reference_including_blanks {
  my ($self, $error_rate_reference_including_blanks, $run_tile) = @_;

  my $errib_object = npg_qc::model::error_rate_reference_including_blanks->new({
    util        => $self->util(),
  });

  my @fields = $errib_object->fields();
  splice @fields, 0, 2;

  my @rows = $error_rate_reference_including_blanks->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $errib = npg_qc::model::error_rate_reference_including_blanks->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      really       => $row->getAttribute('really'),
    });

    foreach my $f (@fields) {
      $errib->{$f} = $row->getAttribute($f);
    }

    $errib->save();

  }

  return;
}

sub table_errors_by_cycle {
  my ($self, $errors_by_cycle, $run_tile) = @_;

  my $ebc_object = npg_qc::model::errors_by_cycle->new({
    util        => $self->util(),
  });

  my @fields = $ebc_object->fields();
  splice @fields, 0, 2;

  my @rows = $errors_by_cycle->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $ebc = npg_qc::model::errors_by_cycle->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
    });

    foreach my $f (@fields) {
      $ebc->{$f} = $row->getAttribute($f);
    }

    $ebc->save();

  }

  return;
}

sub table_error_rate_relative_reference_cycle_nucleotide {
  my ($self, $error_rate_relative_reference_cycle_nucleotide, $run_tile) = @_;

  my $errrcn_object = npg_qc::model::error_rate_relative_reference_cycle_nucleotide->new({
    util        => $self->util(),
  });

  my @fields = $errrcn_object->fields();
  splice @fields, 0, 2;

  my @rows = $error_rate_relative_reference_cycle_nucleotide->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $errrcn = npg_qc::model::error_rate_relative_reference_cycle_nucleotide->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
      read_as     => $row->getAttribute('read_as'),
    });

    foreach my $f (@fields) {
      $errrcn->{$f} = $row->getAttribute($f);
    }

    $errrcn->save();

  }

  return;
}

sub table_information_content_by_cycle {
  my ($self, $information_content_by_cycle, $run_tile) = @_;

  my $icbc_object = npg_qc::model::information_content_by_cycle->new({
    util        => $self->util(),
  });

  my @fields = $icbc_object->fields();
  splice @fields, 0, 2;

  my @rows = $information_content_by_cycle->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $icbc = npg_qc::model::information_content_by_cycle->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
    });

    foreach my $f (@fields) {
      $icbc->{$f} = $row->getAttribute($f);
    }

    $icbc->save();

  }

  return;
}

sub table_log_likelihood {
  my ($self, $log_likelihood, $run_tile) = @_;

  my $log_object = npg_qc::model::log_likelihood->new({
    util        => $self->util(),
  });

  my @fields = $log_object->fields();
  splice @fields, 0, 2;

  my @rows = $log_likelihood->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $log = npg_qc::model::log_likelihood->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
      read_as     => $row->getAttribute('read_as'),
    });

    foreach my $f (@fields) {
      $log->{$f} = $row->getAttribute($f);
    }

    $log->save();

  }

  return;
}

sub table_tile_score {
  my ($self, $tile_score, $run_tile) = @_;

  my $rescore = $tile_score->getAttribute('rescore');

  my $tile_score_object = npg_qc::model::tile_score->new({
    util        => $self->util(),
    id_run_tile => $run_tile->id_run_tile(),
    rescore     => $rescore,
  });

  my @fields = $tile_score_object->fields();
  splice @fields, 0, 2;

  foreach my $f (@fields) {
    $tile_score_object->{$f} = $tile_score->getAttribute($f);
  }

  $tile_score_object->save();

  return;
}

sub table_cumulative_errors_by_cycle {
  my ($self, $cumulative_errors_by_cycle, $run_tile) = @_;

  my $cebc_object = npg_qc::model::cumulative_errors_by_cycle->new({
    util        => $self->util(),
  });

  my @fields = $cebc_object->fields();
  splice @fields, 0, 2;

  my @rows = $cumulative_errors_by_cycle->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $cebc = npg_qc::model::cumulative_errors_by_cycle->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      rescore     => $row->getAttribute('rescore'),
      cycle       => $row->getAttribute('cycle'),
    });

    foreach my $f (@fields) {
      $cebc->{$f} = $row->getAttribute($f);
    }

    $cebc->save();

  }

  return;
}

sub swiftreport {
  my ($self, $parsed_xml) = @_;

  my $report = $parsed_xml->getElementsByTagName('report')->shift();

  my $tag = $report->getAttribute('tag');
  my ($id_run, $position, $tile) = split /:/xms, $tag;

  my $arg_refs = {
    parsed_xml => $parsed_xml,
    id_run     => $id_run,
    tile       => $tile,
    position   => $position,
    end        => 1,
  };

  my $run_tile = $self->get_run_tile($arg_refs);
  $self->swift_report_summary($parsed_xml, $run_tile);

  my $all_intensities = $parsed_xml->getElementsByTagName('averageall')->shift();
  $self->swift_all_intensities($all_intensities, $run_tile);

  my $called_intensities = $parsed_xml->getElementsByTagName('averagecalled')->shift();
  $self->swift_called_intensities($called_intensities, $run_tile);

  my $pf_errors = $parsed_xml->getElementsByTagName('pf')->shift();
  $self->swift_pf_errors($pf_errors, $run_tile);

  my $npf_errors = $parsed_xml->getElementsByTagName('nonpf')->shift();
  $self->swift_npf_errors($npf_errors, $run_tile);

  return $self->response_object('swiftreport');
}

sub swift_all_intensities {
  my ($self, $all_intensities, $run_tile) = @_;

  my $saw = npg_qc::model::swift_all_intensities_per_cycle_per_base->new({util => $self->util});

  my @fields = $saw->fields();
  splice @fields, 0, $THREE;

  my @rows = $all_intensities->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $saw_obj = npg_qc::model::swift_all_intensities_per_cycle_per_base->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      cycle       => $row->getAttribute('cycle'),
    });

    foreach my $f (@fields) {
      $saw_obj->{$f} = $row->getAttribute(uc$f);
    }

    $saw_obj->save();

  }

  return;
}

sub swift_called_intensities {
  my ($self, $called_intensities, $run_tile) = @_;

  my $scw = npg_qc::model::swift_called_intensities_per_cycle_per_base->new({util => $self->util});

  my @fields = $scw->fields();
  splice @fields, 0, $THREE;

  my @rows = $called_intensities->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $scw_obj = npg_qc::model::swift_called_intensities_per_cycle_per_base->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      cycle       => $row->getAttribute('cycle'),
    });

    foreach my $f (@fields) {
      $scw_obj->{$f} = $row->getAttribute(uc$f);
    }

    $scw_obj->save();

  }

  return;
}

sub swift_pf_errors {
  my ($self, $pf_errors, $run_tile) = @_;

  my @rows = $pf_errors->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $spe_obj = npg_qc::model::swift_pf_errors_per_cycle->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      cycle       => $row->getAttribute('cycle'),
      errors      => $row->getAttribute('errors'),
    });
    $spe_obj->save();

  }

  return;
}

sub swift_npf_errors {
  my ($self, $npf_errors, $run_tile) = @_;

  my @rows = $npf_errors->getElementsByTagName('row');

  foreach my $row (@rows) {

    my $sne_obj = npg_qc::model::swift_npf_errors_per_cycle->new({
      util        => $self->util(),
      id_run_tile => $run_tile->id_run_tile(),
      cycle       => $row->getAttribute('cycle'),
      errors      => $row->getAttribute('errors'),
    });

    $sne_obj->save();
  }

  return;
}

sub swift_report_summary {
  my ($self, $parsed_xml, $run_tile) = @_;

  my $summary = $parsed_xml->getElementsByTagName('summary')->shift();
  my $pf_bases = $summary->getElementsByTagName('pfbases')->shift()->getAttribute('value');
  my $npf_bases = $summary->getElementsByTagName('nonpfbases')->shift()->getAttribute('value');
  my $pf_reads = $summary->getElementsByTagName('pfreads')->shift()->getAttribute('value');
  my $npf_reads = $summary->getElementsByTagName('nonpfreads')->shift()->getAttribute('value');
  my $pf = $parsed_xml->getElementsByTagName('pf')->shift();
  my $pf_good_bases = $pf->getElementsByTagName('goodbases')->shift()->getAttribute('value');
  my $pf_unique = $pf->getElementsByTagName('uniquereads')->shift()->getAttribute('value');
  my $npf = $parsed_xml->getElementsByTagName('nonpf')->shift();
  my $npf_good_bases = $npf->getElementsByTagName('goodbases')->shift()->getAttribute('value');
  my $npf_unique = $npf->getElementsByTagName('uniquereads')->shift()->getAttribute('value');

  my $swift_report = npg_qc::model::swift_report->new({
    util            => $self->util(),
    id_run_tile     => $run_tile->id_run_tile(),
    pf_bases        => $pf_bases,
    pf_good_bases   => $pf_good_bases,
    pf_reads        => $pf_reads,
    pf_unique       => $pf_unique,
    npf_bases       => $npf_bases,
    npf_good_bases  => $npf_good_bases,
    npf_reads       => $npf_reads,
    npf_unique      => $npf_unique,
  });
  $swift_report->save();

  return;
}

1;
__END__
=head1 NAME

npg_qc::view::create_xml

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $o = npg_qc::view::create_xml->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 decor - sets decor to 0, as only job is to process and respond with xml

=head2 content_type - sets content_type to 'application/xml'

=head2 render - renders view

=head2 create - overall handler to obtain xml and determine what to do with it

=head2 allowed_datasets - checks that the dataset sent is a suitable dataset to process

=head2 parse_xml - parses the xml string into Lib::XML::Document object

=head2 response_object - creates the xml response object, containing the type of information parsed and saved

=head2 get_run_tile - checks to see if run_tile already exists, saves it if not, and returns run_tile object

=head2 z_log - responsible for saving the z_log info for a run

=head2 z_log_libxml - saving z_log data into database using libxml

=head2 run_config - responsible for saving the run_config dataset

=head2 summary_data - responsible for saving the summary_data dataset

=head2 signal_mean - responsible for saving the signal_mean dataset

=head2 tile_all - responsible for saving the tile_all dataset

=head2 tile_score - responsible for saving the tile_score dataset, using table_<further_dataset> each time

=head2 swiftreport - handler for processing the swiftreport xml

=head2 table_most_common_blank_pattern - responsible for saving the most_common_blank_pattern dataset

=head2 table_most_common_word - responsible for saving the most_common_word dataset

=head2 table_errors_by_cycle_and_nucleotide - responsible for saving the errors_by_cycle_and_nucleotide dataset

=head2 table_errors_by_nucleotide - responsible for saving the errors_by_nucleotide dataset

=head2 table_error_rate_relative_sequence_base - responsible for saving the error_rate_relative_sequence_base dataset

=head2 table_error_rate_reference_no_blanks - responsible for saving the error_rate_reference_no_blanks dataset

=head2 table_error_rate_reference_including_blanks - responsible for saving the error_rate_reference_including_blanks dataset

=head2 table_errors_by_cycle - responsible for saving the errors_by_cycle dataset

=head2 table_error_rate_relative_reference_cycle_nucleotide - responsible for saving the error_rate_relative_reference_cycle_nucleotide dataset

=head2 table_information_content_by_cycle - responsible for saving the information_content_by_cycle dataset

=head2 table_log_likelihood - responsible for saving the log_likelihood dataset

=head2 table_tile_score - responsible for saving the tile_score dataset

=head2 table_cumulative_errors_by_cycle - responsible for saving the cumulative_errors_by_cycle dataset

=head2 swift_report_summary - handles saving out the summary data for the tile

=head2 swift_all_intensities - handles saving out the all intensity scores for the tile

=head2 swift_called_intensities - handles saving out the called intensity scores for the tile

=head2 swift_pf_errors - handles saving out the pf errors for the tile

=head2 swift_npf_errors - handles saving out the non-pf errors for the tile

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
