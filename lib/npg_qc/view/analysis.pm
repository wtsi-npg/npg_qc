#########
# Author:        ajb
# Created:       2009-01-19
#

package npg_qc::view::analysis;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp qw(confess cluck carp croak);
use npg_qc::model::analysis;
use npg_qc::model::chip_summary;

our $VERSION = '0';

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

  my $aspect = $self->aspect();

  if($aspect =~ /xml/xms) {
    return $self->list_xml();
  }

  return $self->SUPER::render();
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
    carp  $EVAL_ERROR;
    $self->return_an_xml_error($EVAL_ERROR);
  };

  return $parsed_xml;
}

sub return_an_xml_error {
  my ($self, $error_string) = @_;
  if ($error_string) {
    $self->{return_an_xml_error} = $self->response_object('<error_string>'.$error_string.'</error_string>');
  }
  return $self->{return_an_xml_error};
}

sub response_object {
  my ($self, $string) = @_;

  my $response_string = qq{<?xml version="1.0" encoding="utf-8"?><response>$string</response>};

  my $parser = $self->util->parser();

  eval {
    $parser->parse_string($response_string);
    1;
  } or do {
    carp $EVAL_ERROR;
    my $error = $self->return_an_xml_error($EVAL_ERROR);
    return $self->response_object($error);
  };
  return $response_string;
}

sub list_xml {
  my ($self) = @_;

  my $util    = $self->util();
  my $cgi     = $util->cgi();

  my $content = $cgi->param('POSTDATA');

  if (!$content) {
    $content = $cgi->param('XForms:Model');
  }

  my $parsed_xml = $self->parse_xml($content);

  if ($self->return_an_xml_error()) {
    return $self->return_an_xml_error();
  }

  return $self->generate_xml_analysis($parsed_xml);
}

sub generate_xml_analysis {
  my ($self, $parsed_xml) = @_;
  my $xml_string = q{};
  my $runs = $parsed_xml->getElementsByTagName('run');
  foreach my $r (@{$runs}) {
    my $id_run = $r->getAttribute('id_run');
    my $analysis = npg_qc::model::analysis->new({
      util => $self->util(),
      id_run => $id_run,
    });
    $xml_string .= '<analysis ';
    foreach my $f ($analysis->fields()) {
      $xml_string .= qq{$f="}.$analysis->$f().q{" };
    }
    my $chip_summary = npg_qc::model::chip_summary->new({
      util   => $self->util(),
      id_run => $id_run,
    });

    if (!$chip_summary) {
      my $id_run_pair = $analysis->id_run_pair();
      $chip_summary = npg_qc::model::chip_summary->new({
        util   => $self->util(),
        id_run => $id_run_pair,
      });
    }
    $xml_string .= q{FC_yield="}.$chip_summary->yield_kb().q{" };
    $xml_string .= ">\n";

    foreach my $al (@{$analysis->analysis_lanes()}) {
      $xml_string .= '  <analysis_lane ';
      foreach my $f ($al->fields()) {
        $xml_string .= qq{$f="}.$al->$f().q{" };
      }
      $xml_string .= "/>\n";
    }
    $xml_string .= '</analysis>';

  }
  return $self->response_object($xml_string);
}
1;
__END__
=head1 NAME

npg_qc::view::analysis

=head1 SYNOPSIS

  my $oAnalysis = npg_qc::view::analysis->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 decor - returns no decor for this view

=head2 content_type - returns application/xml

=head2 render - determines to which render method to call

=head2 parse_xml - parses an xml string with a parser from util (expect XML::LibXML) and returns the object or an error xml string

=head2 return_an_xml_error - takes an error_string and returns it wrapped in some xml

=head2 response_object - takes a string, puts an xml header and a response tag around it, checks it parses, and returns the string, or returns an error xml if it is unable to be parsed

=head2 list_xml - render method for xml

=head2 generate_xml_analysis - goes and creates the relevant xml required for analysis

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
