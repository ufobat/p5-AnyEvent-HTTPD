#!perl
use common::sense;
use Test::More tests => 2;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTPD;
use AnyEvent::Socket;

my $c = AnyEvent->condvar;

my $h = AnyEvent::HTTPD->new;

my $req_url;
my $req_hdr;

$h->reg_cb (
   '/test' => sub {
      my ($httpd, $req) = @_;
      $req_hdr = $req->headers->{'content-type'};
      $req->respond ({
         content => ['text/plain', "Test response"]
      });
   },
);

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
      "GET\040http://localhost:19090/test\040HTTP/1.0\015\012Content-Length:\015\012 10\015\012Content-Type: text/html;\015\012 charSet = \"ISO-8859-1\"; Foo=1\015\012\015\012ABC1234567"
   );
};

my $r = $c->recv;

ok ($r =~ /Test response/m, 'test response ok');
ok ($req_hdr =~ /Foo/, 'test header ok');
