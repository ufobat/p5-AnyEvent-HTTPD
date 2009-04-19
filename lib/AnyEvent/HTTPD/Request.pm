package AnyEvent::HTTPD::Request;
use strict;
no warnings;

=head1 NAME

AnyEvent::HTTPD::Request - A web application request handle for L<AnyEvent::HTTPD>

=head1 DESCRIPTION

This is the request object as generated by L<AnyEvent::HTTPD> and given
in the request callbacks.

=head1 METHODS

=over 4

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { @_ };
   bless $self, $class
}

=item B<url>

This method returns the URL of the current request.

=cut

sub url {
   my ($self) = @_;
   my $url = $self->{url};
   my $u = URI->new ($url);
   $u->query (undef);
   $u
}

=item B<respond ([$res])>

This method will send a response to the request.
If no C<$res> argument was given eventually accumulated output will be
send as C<text/html>.

Otherwise C<$res> can be:

=over 4

=item * an array reference

Then the array reference has these elements:

   my ($code, $message, $header_hash, $content) =
         [200, 'ok', { 'Content-Type' => 'text/html' }, '<h1>Test</h1>' }]

=item * a hash reference

If it was a hash reference the hash is first searched for the C<redirect>
key and if that key does not exist for the C<content> key.

The value for the C<redirect> key should contain the URL that you want to redirect
the request to.

The value for the C<content> key should contain an array reference with the first
value being the content type and the second the content.

=back

Here is an example:

   $httpd->reg_cb (
      '/image/elmex' => sub {
         my ($httpd, $req) = @_;

         open IMG, "$ENV{HOME}/media/images/elmex.png"
            or $req->respond (
                  [404, 'not found', { 'Content-Type' => 'text/plain' }, 'not found']
               );

         $req->respond ({ content => ['image/png', do { local $/; <IMG> }] });
      }
   );

=cut

sub respond {
   my ($self, $res) = @_;

   my $rescb = $self->{resp};

   if (ref $res eq 'HASH') {
      my $h = $res;
      if ($h->{redirect}) {
         $res = [
            301, 'redirected', { Location => $h->{redirect} },
            "Redirected to <a href=\"$h->{redirect}\">here</a>"
         ];
      } elsif ($h->{content}) {
         $res = [
            200, 'ok', { 'Content-Type' => $h->{content}->[0] },
            $h->{content}->[1]
         ];
      }

   }

   $self->{responded} = 1;

   if (not defined $res) {
      $rescb->(404, "ok", { 'Content-Type' => 'text/html' }, "<h1>No content</h1>");

   } else {
      $rescb->(@$res);
   }
}

=item B<responded>

Returns true if this request already has been responded to.

=cut

sub responded {
   my ($self) = @_;
   $self->{responded}
}

=item B<parm ($key)>

Returns the first value of the form parameter C<$key> or undef.

=cut

sub parm {
   my ($self, $key) = @_;
   if (exists $self->{parm}->{$key}) {
      return $self->{parm}->{$key}->[0]->[0]
   }
   return undef;
}

=item B<vars>

Returns a hash of form parameters. The value is either the 
value of the parameter, and in case there are multiple values
present it will contain an array reference of values.

=cut

sub vars {
   my ($self) = @_;

   my $p = $self->{parm};

   my %v = map {
      my $k = $_;
      $k =>
         @{$p->{$k}} > 1
            ? [ map { $_->[0] } @{$p->{$k}} ]
            : $p->{$k}->[0]->[0]
   } keys %$p;

   %v
}

=item B<content>

Returns the request content or undef if only parameters for a form
were transmitted.

=cut

sub content {
   my ($self) = @_;
   return $self->{content};
}

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
