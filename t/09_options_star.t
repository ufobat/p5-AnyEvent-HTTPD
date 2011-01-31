#!perl
use common::sense;
use Test::More tests => 34;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::HTTPD;
use AnyEvent::Socket;

use bytes ();
use Compress::Zlib;
use HTTP::Date     ();
use HTTP::Response ();

my $c = AnyEvent->condvar;
my $h = AnyEvent::HTTPD->new( allowed_methods => [qw/GET HEAD POST OPTIONS/] );

my ( $H, $P );

# mimic the conversation from:
# https://developer.mozilla.org/En/HTTP_Access_Control#Preflighted_requests
# as a test scenario

my $req_1_content = undef;
my $req_1_headers = {
  'Host' => 'bar.other',
  'User-Agent' =>
    'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1b3pre) Gecko/20081130 Minefield/3.1b3pre',
  'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language' => 'en-us,en;q=0.5',
  'Accept-Encoding' => 'gzip,deflate',
  'Accept-Charset'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
  'Keep-Alive'      => 300,
  'Origin'          => 'http://foo.example',
  'Access-Control-Request-Method'  => 'POST',
  'Access-Control-Request-Headers' => 'X-PINGOTHER',
  'Content-Length'                 => 0,
  'Referer' => sprintf( 'http://127.0.0.1:%d/resources/post-here/', $h->port ),
};

my $resp_1_content = '';
my $resp_1_headers = {
  'Date'                         => HTTP::Date::time2str(time),
  'Server'                       => 'AnyEvent::HTTPD ' . $AnyEvent::HTTPD::VERSION,
  'Access-Control-Allow-Origin'  => 'http://foo.example',
  'Access-Control-Allow-Methods' => 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers' => 'X-PINGOTHER',
  'Access-Control-Max-Age'       => 1728000,
  'Vary'                         => 'Accept-Encoding',
  'Content-Encoding'             => 'gzip',
  'Content-Length'               => bytes::length($resp_1_content),
  'Keep-Alive'                   => 'timeout=2, max=100',
  'Content-Type'                 => 'text/plain',
};

$h->reg_cb(
  '*' => sub {
    my ( $httpd, $req ) = @_;
    if ( $req->method eq 'OPTIONS' )
    {
      ok( 1, "options method" );
      while ( my ( $header, $value ) = each %$req_1_headers )
      {
        $header = lc($header);
        if ( !ok( $value eq $req->headers->{$header}, "options header matches $header" ) )
        {
          diag explain "wanted: $value";
          diag explain "got: " . $req->headers->{$header};
        }
      }
      ok( $req->content eq $req_1_content, "options content match" );
      $req->respond( [ 200, 'OK', $resp_1_headers, $resp_1_content ] );
      $httpd->stop_request();
    }
    else
    {
      diag explain 'unknown method';
      die;
    }
  },
  client_connected => sub {
    my ( $httpd, $h, $p ) = @_;
    ok( $h ne '', "got client host" );
    ok( $p ne '', "got client port" );
    ( $H, $P ) = ( $h, $p );
  },
  client_disconnected => sub {
    my ( $httpd, $h, $p ) = @_;
    is( $h, $H, "got client host disconnect" );
    is( $p, $P, "got client port disconnect" );
  }
);

my ( $hdl, $buf );
tcp_connect(
  '127.0.0.1',
  $h->port,
  sub {
    my ($fh) = @_
      or die "couldn't connect";

    $hdl = AnyEvent::Handle->new(
      fh      => $fh,
      on_eof  => sub { $c->send; },
      on_read => sub {
        $buf .= $hdl->rbuf;
        $hdl->rbuf = '';
        if ( $buf =~ m{\015\012\015\012} )
        {
          $c->send($buf);
        }
      }
    );

    my $req_string = "OPTIONS\040*\040HTTP/1.1\015\012";
    while ( my ( $key, $val ) = each %$req_1_headers )
    {
      $req_string .= "$key: $val\015\012";
    }
    $req_string .= "\015\012";
    $hdl->push_write($req_string);
  }
);

my $resp = HTTP::Response->parse( $c->recv );
ok( $resp->is_success, "resp ok" )
  or diag explain $resp->status_line;
ok( $resp->content eq $resp_1_content, "resp content ok" )
  or diag explain $resp->decoded_content;

while ( my ( $key, $val ) = each %$resp_1_headers )
{
  ok( $val eq $resp->header($key), "resp header $key" )
    or diag explain "$key wanted: '$val', got: '" . $resp->header($key) . "'\n";
}

done_testing();

