#!perl
use common::sense;
use Test::More tests => 1;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::HTTPD;
use AnyEvent::Socket;
use File::Temp qw/tempfile/;

my $c = AnyEvent->condvar;

my $key = <<SSLPEM;
-----BEGIN CERTIFICATE-----
MIIDRTCCAi2gAwIBAgIJAPT0ruOR9lGVMA0GCSqGSIb3DQEBBQUAMCAxHjAcBgNV
BAMTFUFueUV2ZW50OjpIVFRQRDo6VGVzdDAeFw0xMTAyMDMwOTIzMjVaFw0yMTAx
MzEwOTIzMjVaMCAxHjAcBgNVBAMTFUFueUV2ZW50OjpIVFRQRDo6VGVzdDCCASIw
DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMvcrbdrKjNJnErDH0fEk4gW73+R
9w1QshLZJbYN/0J0XKVl4dVnbt1847GFJI33w3GE+M3M/vQTeb9Qt55BF+nXO6EC
CeWyaODBzFuYcKcUvWKPvokncVnCtuMOxqif44LaQy7OssmO57odnJPdvHQJNlbZ
eH0fIF+dhO6+300qsmMT51++3ey+oV5KQ31Ij5YG5CbMo6R8rp9vh+7Q7GiynsCT
pKnoyiNcUM+gDilz8F+J4yxNK/cSKP0J2ihTE3kt9UC6E34zNXDx9yBvk9d+Bszy
CQMDQpIm68ALMWybW8i0OZmajD/wQrivuOAm4x/DstmzqFgsTVCxjkT1PdkCAwEA
AaOBgTB/MB0GA1UdDgQWBBRyOD6j/IlV2ZDgWqQYtxeDr33ZJTBQBgNVHSMESTBH
gBRyOD6j/IlV2ZDgWqQYtxeDr33ZJaEkpCIwIDEeMBwGA1UEAxMVQW55RXZlbnQ6
OkhUVFBEOjpUZXN0ggkA9PSu45H2UZUwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQUFAAOCAQEAtOnVFExzVfehiwUBr8YDkN87Y7vQ02HWu+IUU5ZmXE2z4Zepxugu
lIKlXnV8im7ygLeUtNrw+N8Z1G1k8PmvqesucM8pqAq4wNxZUSdhRRElrkYWMFKG
YWjEQ9J5qvdmXWqnCd15o/D91w49PUkI6GQWR6gWp/wPz24B3TMOFN64dxYfoM2p
RZFqnzHm4H/Hgm3KDzAn5k8rTFtziZ69dIbuDuqbIZQJq0aqCDaICqMTxYclZTOs
1b839P/dEgB1oOXjPFf5QUKxyo+UXC4qb8OYepwY5ej8x+KgiKa9E3wNS1oNqsK9
FsLaMbcklpM+tpIJ9tmACXW03WwfhmaUCQ==
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAy9ytt2sqM0mcSsMfR8STiBbvf5H3DVCyEtkltg3/QnRcpWXh
1Wdu3XzjsYUkjffDcYT4zcz+9BN5v1C3nkEX6dc7oQIJ5bJo4MHMW5hwpxS9Yo++
iSdxWcK24w7GqJ/jgtpDLs6yyY7nuh2ck928dAk2Vtl4fR8gX52E7r7fTSqyYxPn
X77d7L6hXkpDfUiPlgbkJsyjpHyun2+H7tDsaLKewJOkqejKI1xQz6AOKXPwX4nj
LE0r9xIo/QnaKFMTeS31QLoTfjM1cPH3IG+T134GzPIJAwNCkibrwAsxbJtbyLQ5
mZqMP/BCuK+44CbjH8Oy2bOoWCxNULGORPU92QIDAQABAoIBAFmroPHL/oz+tPOh
rjGoQuiahhBMCSpfM2TdBRx2PbBidJoAHXz7+SUNmS3tja2wrNRTFAmaQQ7lPikr
/QhsQ3OFS+I/flD9z+oE9LnZbLvhgIhJCBtWMSK1ZjKrvjBP3Agjr2d4XeYQqNcR
zVyxLQKxRqifEcOfnGLSa7WEWb6b3z4nCNsDTW8+gthmJqRXqKpJ7F7pucjtIx/k
HIlPw/XT+UEm4BqXc/kFhy3orGtweTOs1rOdUA8vZlN48FPFS4jj2ladOoPP7BU1
nxS4UTU/jAxTTZKXRPvs0wCA3e7/XtnTVLdDAhcDJGzFgdeEKTmDslcuV5pU+gbG
diI6dk0CgYEA6p1LDgAXWdcPHMJvc2tUls8pHqQheOZ2y0sS9jBndUH2bUU2XtcN
CVADeDwGss0G9vBI7oBonWUfa8GcUSQdNrTtb1zvVwaJMdWsZV58r4VjttvnUafd
p0/rM4B4flB0pgsE0lFkNl3xJQ2N1u+S6yGONlF5paPlbUCicmDChwsCgYEA3nHH
5hldAQnLhskMRvMpU34DiOJfo/TH/7hvQA5+hNJ1jDRhf2Rn6P89PlE6HmmonpE9
QhIHLR6IRkKngBygXT+7mwfA0MJYhKGNjXlh1l+Kj1mUqvWwGACUuvHy/yD4fOmZ
Eqmtyy+cUNSGd58XBYDTMFRAYT2eVjP8RipnDSsCgYAGi0Sgq1f7ZYhCYRoCuiet
3TFkbWeRm7wMh5eLzmXUW3aoLZoKoyz16YlvPR1it11OXf1qyaIhYcSymL/nc35t
HDbTOGBkqQYCodchLLWFn87cNt4I5QnFtPD2isrRmyTlzMDhrOuCqLQlOG+QYzZR
4Km60iL2f8/ScE8XqaNDaQKBgGKiiUUakgbX1QubMnpzcCu5gM+9sTL+Y4Ccw5ff
1XIH8F+PCnx2hSznoLx1QBQkPcSyGjulytDS7RJak/NWvjUbAZEoyvLGeoG1MRM+
c4efLc2Kp0V3U/IQr+KFTn6anBSncFy6KHokTmf5FPcN8CNckEip0zJLJF6NBpwG
SVOpAoGBALKXVEgnACuYacLq5SB+5QNMJkPSUQk4TOyYBB0Gt6wOfejBLCk1yu78
shBA3etGsmveEkGRUNmTNwKV12Jgvxkvmpv687rUtYO3AdQK9ZukKg97TWmQxFr5
9mndYvsq3xM2wB8/+LFA/repXZTL56KpPU+pO0SVu/mBnUK6VwrB
-----END RSA PRIVATE KEY-----
SSLPEM

my $h = AnyEvent::HTTPD->new (ssl => { cert => $key });

$h->reg_cb (
   '/test' => sub {
      my ($httpd, $req) = @_;
      $req->respond ({ content => ['text/plain', "31337"] });
   },
);

my $hdl;
my $buf;
tcp_connect '127.0.0.1', $h->port, sub {
   my ($fh) = @_
      or die "couldn't connect: $!";

   $hdl =
      AnyEvent::Handle->new (
         fh => $fh, on_eof => sub { $c->send },
         tls => "connect",
         on_read => sub {
            $buf .= $hdl->rbuf;
            $hdl->rbuf = '';
         });

   $hdl->push_write (
      "GET\040http://localhost:19090/test\040HTTP/1.0\015\012\015\012"
   );
};

$c->recv;

ok ($buf =~ /31337/, "encrypted data received");
