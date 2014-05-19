#########
# Author:        ajb
# Created:       2008-06-16
#

package npg_qc::view::error;
use strict;
use warnings;
use base qw(ClearPress::view::error);
use English qw(-no_match_vars);
use Carp;
use Template;

our $VERSION = '0';

__PACKAGE__->mk_accessors('access');

sub render {
  my $self   = shift;
  my $errstr = q(Error: ) . $self->errstr();
  my $aspect = $self->aspect();

  print {*STDERR} qq[Serving error:\nerrstr:     @{[$self->errstr()||q[undef]]}\nEVAL_ERROR: @{[$EVAL_ERROR||q[undef]]}\nTemplate:   @{[Template->error()||q[undef]]}\n] or croak 'unable to print error';

  if ($aspect eq 'add') {
    $errstr .= q(<br /><br />You do not have sufficient permissions to perform this action. You may have forgotten to log in.<br />Click <a href="https://enigma.sanger.ac.uk/sso/login">here</a> to login or use the key icon.<br /><br />);
  }

  if(Template->error()) {
    $errstr .= q(Template Error: ) . Template->error();
  }

  if($EVAL_ERROR) {
    $errstr .= q(Eval Error: ) . $EVAL_ERROR;
  }


  $errstr    =~ s{\S+(npg.*?)$}{$1}smgx;
  return q(<h2>An Error Occurred</h2>) .  $self->actions() . q(<p>) . $errstr . q(</p>);
}

1;

__END__

=head1 NAME

npg_qc::view::error

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 render - encapsulated HTML rather than a template, in case the template has caused the error

  my $sErrorOutput = $oErrorView->render();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

ClearPress::view::error
strict
warnings
base
English
Template

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
