package Catalyst::Controller::AjaxProxy;

use Moose;
use Carp;
use English qw(-no_match_vars);
use namespace::autoclean;
use HTTP::Request;
use LWP::UserAgent;
use Readonly;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION   = '0';
## no critic (Documentation::RequirePodAtEnd Subroutines::ProhibitBuiltinHomonyms)

=head1 NAME

Catalyst::Controller::AjaxProxy

=head1 SYNOPSIS

  package MyApp::Controller::MyProxy;
  use parent qw/Catalyst::Controller::AjaxProxy/;

=head1 DESCRIPTION

A Catalyst Controller implementing a proxy for Ajax calls.
If both the remote_sites and protocols attributes set,
uses the validate method to validate the requested URLs.

Request example: http://localhost:3000/myproxy?url=http://www.othersite.com/somepage

Example of configuration in the XML configuration file:

  <Controller MyProxy>
    remote_sites  internal.npgtest.dodo
    remote_sites  www.npgtest.dodo
    protocols     http
    protocols     https
  </Controller>

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $INTERNAL_SERVER_ERROR  => 500;
Readonly::Scalar our $FORBIDDEN              => 403;
Readonly::Scalar our $MIN_NUM_URL_TOKENS     => 4;
Readonly::Scalar our $URL_FIELD_NAME         => q[url];
Readonly::Scalar our $PAYLOAD_FIELD_NAME     => q[XForms:Model];


=head2 remote_sites

A reference to an array of allowed remote sites to connect to

=cut
has 'remote_sites' =>  (isa      => 'Maybe[ArrayRef]',
                        is       => 'rw',
                        required => 0,
                       );

=head2 protocols

A reference to an array of allowed protocols.

=cut
has 'protocols'  => (isa      => 'Maybe[ArrayRef]',
                     is       => 'rw',
                     required => 0,
                    );


=head2 validate

If both the remote_sites and protocols attributes set, validates URL.
Returns either 0 or 1.

=cut
sub validate{
    my ($self, $url) = @_;
    if (!$url) {
        croak 'Empty URL in validate()';
    }
    #TODO:  replace with Perl URI module?

    if (!$self->protocols || !$self->remote_sites) {
        return 1;
    }

    my @components = split m{ [:/] }smx, $url;
    if ((scalar @components) < $MIN_NUM_URL_TOKENS || $components[1] || $components[2]) {
        croak qq[Wrong URL format: $url];
    }

    my $protocol = $components[0];
    ## no critic (ProhibitMagicNumbers)
    my $domain = $components[3];
    ## use critic

    foreach my $p (@{$self->protocols}) {
        if ($p eq $protocol) {
            foreach my $s (@{$self->remote_sites}) {
                if ($s eq $domain) {
                    return 1;
		}
	    }
	    last;
	}
    }

    return 0;
}


=head2 index

Index page action

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $requested_url = $c->request->params->{$URL_FIELD_NAME};
    eval {
        if (!$requested_url) {
            $c->response->status($INTERNAL_SERVER_ERROR);  #500 for internal server error
            croak q[url parameter is missing in the request];
        }
        if(!$self->validate($requested_url)) {
            croak qq[Cannot proxy to $requested_url];
        }
        1;
    } or do {
        if ($c->response->status != $INTERNAL_SERVER_ERROR) {
             $c->response->status($FORBIDDEN);
	}
        $c->response->header(q[Content-Type] => q[text/xml]);
        $c->response->body(q[<xml><error>] . $EVAL_ERROR . q[</error></xml>]);
        return;
    };

    my $method = $c->request->method;
    my $request = HTTP::Request->new( $method => $requested_url);

    my $h = $c->request->headers;
    foreach my $header ($h->header_field_names) {
        if ($header ne q[Accept-Encoding]) {
            $request->headers->header($header => $h->header($header));
        }
    }

    if ($method eq q[POST]) {
        if ($c->request->params->{$PAYLOAD_FIELD_NAME}) {
            $request->content($c->request->params->{$PAYLOAD_FIELD_NAME});
        } else {
            my %params = %{$c->request->params};
            delete $params{$URL_FIELD_NAME};
            delete $params{q[_]};
            $request->content(%params);
        }
    }

    my $ua = LWP::UserAgent->new();
    $ua->agent(q[NPG_INTERACTIVE_SEQQC_AJAXPROXY]);
    my $response = $ua->request($request);
    $c->response->status($response->code);
    $c->response->body($response->content);
    $c->response->headers($response->headers);

    return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item English

=item Readonly

=item namespace::autoclean

=item Moose

=item Catalyst::Controller

=item HTTP::Request

=item LWP::UserAgent

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
