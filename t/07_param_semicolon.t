#!perl
use common::sense;
use Test::More tests => 2;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTPD;

my $h = AnyEvent::HTTPD->new (port => 19090);

my $req_q;
my $req_n;

$h->reg_cb (
   '/test' => sub {
      my ($httpd, $req) = @_;
      $req_q = $req->parm ('q');
      $req_n = $req->parm ('n');
      $req->respond ({ content => ['text/plain', "Test response"] });
   },
);

my $c;
my $t = AnyEvent->timer (after => 0.1, cb => sub {
   my $p = fork;
   if (defined $p) {
      if ($p) {
         $c = AnyEvent->child (pid => $p, cb => sub { $h->stop });
      } else {
         `wget 'http://localhost:19090/test?q=%3F%3F;n=%3F2%3F' -O- 2>/dev/null`;
         exit;
      }
   } else {
      die "fork error: $!";
   }
});

$h->run;

is ($req_q, "??", "parameter q correct");
is ($req_n, "?2?", "parameter n correct");
