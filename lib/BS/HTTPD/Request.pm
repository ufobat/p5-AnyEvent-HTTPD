package BS::HTTPD::Request;
use feature ':5.10';
use strict;
no warnings;

=head1 NAME

BS::HTTPD::Request - A web application request handle for L<BS::HTTPD>

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
   my $url = $self->{cur_url};
   my $u = URI->new ($url);
   $u->query (undef);
   $u
}

sub is_form_submit {
   my ($self) = @_;
   defined $self->form_id
}

sub form_id {
   my ($self) = @_;
   my $id = $self->parm ("_APP_SRV_FORM_ID");
   $id = $self->parm ("a") if defined $self->parm ("a");
   $id
}

=item B<form ($content, $callback)>

This method will create a form for you and bind it to the C<$handler>
you gave. The content of the form tag can be given by C<$content>, which
can either be a string or a code reference, which will be called and should
return the form content.

When the form is submitted the C<$callback> will be called before the submit
request executes any of your content callbacks. The form ID is transmitted via
a hidden input element with the name C<_APP_SRV_FORM_ID>, and you should take
care not to use that form element name yourself.

The C<$callback> will receive as first argument the L<BS::HTTPD> object.

You can access the transmitted form parameters via the C<parm> method.

=cut

sub form {
   my ($self, $cont, $cb) = @_;
   my $id = $self->{httpd}->alloc_id ($cb);
   my $url = $self->url;
   '<form action="'.$url.'" method="POST" enctype="multipart/form-data">'
   .'<input type="hidden" name="_APP_SRV_FORM_ID" value="'.$id.'" />'
   .(ref $cont ? $cont->() : $cont)
   .'</form>'
}

=item B<respond ([$res])>

This method will send a response to the request.
If no C<$res> argument was given eventually accumulated output will be
send as C<text/html>.

Otherweis C<$res> can be:

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
      _image_elmex => sub {
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

   if (not defined $res) {
      if ($self->{output} eq '') {
         $rescb->(404, "ok", { 'Content-Type' => 'text/html' }, "<h1>No content</h1>");
      } else {
         $rescb->(200, "ok", { 'Content-Type' => 'text/html' }, $self->{output});
      }
   } else {
      $rescb->(@$res);
   }
}

sub link {
   my ($self, $lbl, $cb, $newurl) = @_;
   my $id = $self->{httpd}->alloc_id ($cb);
   $newurl //= $self->url;
   '<a href="'.$newurl.'?a='.$id.'">'.$lbl.'</a>';
}

sub parm {
   my ($self, $key) = @_;
   if (exists $self->{parm}->{$key}) {
      return $self->{parm}->{$key}->[0]->[0]
   }
   return undef;
}

sub content {
   my ($self) = @_;
   return $self->{content};
}

sub o { shift->{output} .= join '', @_ }


1;
