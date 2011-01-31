#!perl
use common::sense;
use Test::More tests => 56;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::HTTPD;
use AnyEvent::Socket;

use bytes ();
use Compress::Zlib;
use HTTP::Date     ();

my $c = AnyEvent->condvar;
my $h = AnyEvent::HTTPD->new( allowed_methods =>  [qw/GET HEAD POST OPTIONS/] );

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

my $req_2_content = '<?xml version="1.0" ?><person><name>nrh</name></person>';
my $req_2_headers = {
  'Host' => 'bar.other',
  'User-Agent' =>
    'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1b3pre) Gecko/20081130 Minefield/3.1b3pre',
  'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language' => 'en-us,en;q=0.5',
  'Accept-Encoding' => 'gzip,deflate',
  'Accept-Charset'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
  'Keep-Alive'      => 300,
  'X-PINGOTHER'     => 'pingpong',
  'Content-Type'    => 'text/xml; charset=UTF-8',
  'Referer'         => 'http://foo.example/examples/preflightInvocation.html',
  'Content-Length'  => bytes::length($req_2_content),
  'Origin'          => 'http://foo.example',
  'Pragma'          => 'no-cache',
  'Cache-Control'   => 'no-cache',
};

my $resp_2_content =
  Compress::Zlib::memGzip('<?xml version="1.0" ?><person><your-mother>nrh</your-mother></person>');
my $resp_2_headers = {
  'Date'                        => HTTP::Date::time2str(time),
  'Server'                      => 'AnyEvent::HTTPD ' . $AnyEvent::HTTPD::VERSION,
  'Access-Control-Allow-Origin' => 'http://foo.example',
  'Vary'                        => 'Accept-Encoding',
  'Content-Encoding'            => 'gzip',
  'Keep-Alive'                  => 'timeout=2, max=99',
  'Content-Type'                => 'text/plain',
  'Content-Length'              => bytes::length($resp_2_content),
};

$h->reg_cb(
  '/resources/post-here/' => sub {
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
          diag explain "got: ". $req->headers->{$header};
        }
      }
      ok( $req->content eq $req_1_content, "options content match" );
      $req->respond( [ 200, 'OK', $resp_1_headers, $resp_1_content ] );
      $httpd->stop_request();
    }
    elsif ( $req->method eq 'POST' )
    {
      ok( 1, "post method" );
      while ( my ( $header, $value ) = each %$req_2_headers )
      {
        $header = lc($header);
        if ( !ok( $value eq $req->headers->{$header}, "options header matches $header" ) )
        {
          diag explain "wanted: $value";
          diag explain "got: " . $req->headers->{$header};
        }
      }
      ok( $req->content eq $req_2_content, "post content match" );
      $req->respond( [ 200, 'OK', $resp_2_headers, $resp_2_content ] );
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
    ( $H, $P ) = ( $h, $p );
  },
);

my $guard;
$guard = http_request(
  OPTIONS => sprintf( 'http://127.0.0.1:%d/resources/post-here/', $h->port ),
  headers => $req_1_headers,
  sub {
    my ( $data, $headers ) = @_;

    while (my ($hdr, $value) = each %$resp_1_headers)
    {
      $hdr = lc($hdr);
      if(!ok( $value eq $headers->{$hdr}, "options response header $hdr"))
      {
        diag explain "wanted: " . $value;
        diag explain "got: " . $headers->{$hdr};
      }
    }

    ok( $data eq $resp_1_content, "options response content" );

    $guard = http_request(
      POST    => sprintf( 'http://127.0.0.1:%d/resources/post-here/', $h->port ),
      headers => $req_2_headers,
      body    => $req_2_content,
      sub {
        my ( $data, $headers ) = @_;
        while (my ($hdr, $value) = each %$resp_2_headers)
        {
          $hdr = lc($hdr);
          if(!ok( $value eq $headers->{$hdr}, "post response header $hdr"))
          {
            diag explain "wanted: " . $value;
            diag explain "got: " . $headers->{$hdr};
          }
        }

        ok( $data eq $resp_2_content, "post response content" );

        # cleanup
        undef $guard;
        $h->stop();
      }
    );
  }
);

$h->run;

done_testing();

