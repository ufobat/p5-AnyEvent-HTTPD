#!perl
use common::sense;
use Test::More tests => 4;
use AnyEvent::Impl::Perl;
use AnyEvent;
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

my $c;
my $t = AnyEvent->timer (after => 0.1, cb => sub {
   my $p = fork;
   if (defined $p) {
      if ($p) {
         $c = AnyEvent->child (pid => $p, cb => sub {
            $h->stop;
         });
      } else {
         my $out = `wget http://localhost:19090/test -O/tmp/anyevent_httpd_test 2>&1 >/dev/null`;
         exit;
      }
   } else {
      die "fork error: $!";
   }
});

$h->run;

is ($req_url, "/test", "the path of the request URL was ok");
is ($req_url2, "/test", "the path of the second request URL was ok");
is ($req_method, 'GET', 'Correct method used');
is (`cat /tmp/anyevent_httpd_test`, 'Test response', "the response text was ok");
