package npg_qc_viewer;

use Moose;
use namespace::autoclean;

use Catalyst::Runtime '5.80';

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use Catalyst   (
                 'ConfigLoader',
                 'Static::Simple',
                 'StackTrace',
                 'Authentication',
                 'Authorization::Roles',
                 '-Log=warn,fatal,error'
               );

extends 'Catalyst';

our $VERSION = '0';

# Configure the application. 
#
# Note that settings in npg_qc_viewer.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
                      name => 'npg_qc_viewer',
                      # Disable deprecated behavior needed by old applications
                      disable_component_resolution_regex_fallback => 1,
                      enable_catalyst_header => 1, # Send X-Catalyst header
                      'Plugin::ConfigLoader' => {
                           driver => {
                               'General' => { -AllowMultiOptions => 'yes',  -ForceArray => 'yes',}
                                     }
                      },
                      encoding => 'UTF-8', 
                      default_view => 'TT',
                   );

my @extra_plugins;

if( $ENV{CATALYST_AUTOCRUD} ) {
    push @extra_plugins, qw/AutoCRUD/;
}

# Start the application
__PACKAGE__->setup(@extra_plugins);

1;

=head1 NAME

npg_qc_viewer - Catalyst based application

=head1 SYNOPSIS

  bin/npg_qc_viewer_server.pl

=head1 DESCRIPTION

NPG SeqQC - a Catalyst-base web application to visualize and datamine QC data

=head1 SEE ALSO

L<npg_qc_viewer::Controller::Root>, L<Catalyst>

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

Can be configured by using npg_qc_viwer.config file

=head1 DEPENDENCIES

=over

=item Catalyst::Runtime

=item namespace::autoclean

=item Moose

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

This file is part of NPG software.

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

