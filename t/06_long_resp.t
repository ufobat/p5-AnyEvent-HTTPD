#!perl
use common::sense;
use Test::More tests => 2;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTPD;
use AnyEvent::Socket;

my $c = AnyEvent->condvar;

my $h = AnyEvent::HTTPD->new;

my $SEND = "ELMEXBLABLA1235869302893095934";#"ABCDEF" x 1024;
my $SENT = $SEND;

$h->reg_cb (
   '/test' => sub {
      my ($httpd, $req) = @_;
      $req->respond ({
         content => ['text/plain', sub {
            my ($data_cb) = @_;
            return unless $data_cb;
            $data_cb->(substr $SENT, 0, 10, '');
         }]
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
      "GET\040http://localhost:19090/test\040HTTP/1.0\015\012\015\012"
   );
};

my $r = $c->recv;

$buf =~ s/^.*?\015?\012\015?\012//s;
ok (length ($buf) == length ($SEND), 'sent all data');
ok (length ($SENT) == 0, 'send buf empty');
