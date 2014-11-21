use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use Test::MockObject;
use HTTP::Response;


package MockCatalystContext;
use Moose;
use namespace::autoclean;
use Catalyst::Request;
use Catalyst::Response;
use File::Temp qw/ tempdir /;

my $log = join q[/], tempdir( CLEANUP => 1 ), 'log';

has 'response' =>  (isa      => 'Catalyst::Response',
                    is       => 'ro',
                    required => 0,
		    default => sub {Catalyst::Response->new(_log=>$log)},
                   );
has 'request' =>   (isa      => 'Catalyst::Request',
                    is       => 'ro',
                    required => 0,
		    default => sub {Catalyst::Request->new(_log=>$log)},
                   );
1;

package main;

{
  use_ok 'Catalyst::Controller::AjaxProxy';
  isa_ok (Catalyst::Controller::AjaxProxy->new(), 'Catalyst::Controller::AjaxProxy');
}

{
  my $ap = Catalyst::Controller::AjaxProxy->new();
  throws_ok {$ap->validate()} qr/Empty URL in validate()/, 'missing url croak';
  is ($ap->validate(q[www.any.com]), 1, 'any url valid');
  $ap = Catalyst::Controller::AjaxProxy->new(protocols => ['http']);
  is ($ap->validate(q[www.any.com]), 1, 'any url valid');
  $ap = Catalyst::Controller::AjaxProxy->new(remote_sites => ['dodo.com']);
  is ($ap->validate(q[www.any.com]), 1, 'any url valid');
}

{
  my $ap = Catalyst::Controller::AjaxProxy->new(
                   protocols => [qw/http https/], 
                   remote_sites => [qw/www.any.com internal.dodo.com/]);
  throws_ok {$ap->validate(q[http:/cvxcv/sanger])} qr/Wrong URL format/, 'wrong url format croak';
  throws_ok {$ap->validate(q[www.any.com])} qr/Wrong URL format/, 'wrong url format croak';
  is($ap->validate(q[http://www.google.com]), 0, 'http://www.google.com not allowed');
  is($ap->validate(q[ftp://www.any.com]), 0, 'ftp://www.any.com not allowed');
  is($ap->validate(q[http://internal.dodo.com]), 1, 'http://internal.dodo.com allowed');
  is($ap->validate(q[https://internal.dodo.com/mypage]), 1, 'https://internal.dodo.com/mypage allowed');
  is($ap->validate(q[http://www.any.com:8080]), 1, 'http://www.any.com:8080 allowed');
  is($ap->validate(q[https://www.any.com:8080/mypage]), 1, 'https://www.any.com:8080/mypage allowed');
}


{
  my $ap =  Catalyst::Controller::AjaxProxy->new();
  my $con = MockCatalystContext->new();
  $ap->index($con);
  
  is( $con->response->status, 500, q[error code is 500] );
  like ($con->response->body, qr/url parameter is missing in the request/, 'absent url parameter error');
}


{
  my $url = '/ajaxproxy?url=http:/cvxcv/sanger';
  my $ap =  Catalyst::Controller::AjaxProxy->new( 
                   protocols => [qw/http https/], 
                   remote_sites => [qw/www.any.com internal.dodo.com/]
                                                );
  my $con = MockCatalystContext->new();
  $con->request->params->{url} = $url;
  $ap->index($con);

  is( $con->response->status, 403, q[error code is 403] );
  like ($con->response->body, qr/Wrong URL format/, 'wrong format url  error');
}


{
  my $url = 'http://dodo.com/dodo';
  my $ap =  Catalyst::Controller::AjaxProxy->new( 
                   protocols => [qw/http https/], 
                   remote_sites => [qw/www.any.com internal.dodo.com/]
                                                );
  my $con = MockCatalystContext->new();
  $con->request->params->{url} = $url;
  $ap->index($con);

  is( $con->response->code, 403, q[error code is 403] );
  like ($con->response->body, qr/Cannot proxy to http:\/\/dodo.com\/dodo/, 'cannot proxy error');
}


{
  my $content = q[All is well];

  my $mockUA = Test::MockObject->new();
  $mockUA->fake_new(q{LWP::UserAgent});

  my $fake_response = HTTP::Response->new(200, '200 Ok', undef, "$content");
  $mockUA->set_always('request', $fake_response);
  $mockUA->set_always('agent', 'npg_agent');
  my $url = 'http://mysite/checks';
  my $ap =  Catalyst::Controller::AjaxProxy->new();
  my $con = MockCatalystContext->new();
  $con->request->params->{url} = $url;
  $con->request->method(q[GET]);
  $ap->index($con);
  
  is( $con->response->code, 200, q[code is 200] );
  like ($con->response->body, qr/$content/, 'expected content returned'); 
}

1;


