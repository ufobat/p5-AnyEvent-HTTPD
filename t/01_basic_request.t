#!perl
use common::sense;
use Test::More tests => 4;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::HTTPD;

my $h = AnyEvent::HTTPD->new (port => 19090);

my $req_url;
my $req_url2;
my $req_method;

$h->reg_cb (
   '' => sub {
      my ($httpd, $req) = @_;
      $req_url = $req->url->path;
   },
   '/test' => sub {
      my ($httpd, $req) = @_;
      $req_url2 = $req->url->path;
      $req_method = $req->method;
      $req->respond ({ content => ['text/plain', "Test response"] });
   },
);

my $c = AE::cv;

my $t = AnyEvent->timer (after => 0.1, cb => sub {
   my $hdl;
   my $buf;
   tcp_connect '127.0.0.1', $h->port, sub {
      my ($fh) = @_
         or die "couldn't connect: $!";

      $hdl =
         AnyEvent::Handle->new (
            fh => $fh, on_eof => sub { $c->send ($buf) },
            on_read => sub {
               $buf .= $hdl->rbuf;
               $hdl->rbuf = '';
            });
      $hdl->push_write (
         "GET\040http://localhost:19090/test\040HTTP/1.0\015\012\015\012"
      );
   };
});

my $buf = $c->recv;
my ($head, $body) = split /\015\012\015\012/, $buf, 2;

is ($req_url, "/test", "the path of the request URL was ok");
is ($req_url2, "/test", "the path of the second request URL was ok");
is ($req_method, 'GET', 'Correct method used');
is ($body, 'Test response', "the response text was ok");
