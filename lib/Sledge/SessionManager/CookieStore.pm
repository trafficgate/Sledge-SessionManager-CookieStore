package Sledge::SessionManager::CookieStore;

use strict;
use vars qw($VERSION);
$VERSION = 0.02;

use CGI::Cookie;
use base qw(Sledge::SessionManager);

use Sledge::Exceptions;
use Storable;
use MIME::Base64;
use Crypt::CBC;

use vars qw($MaxCookieSize);
$MaxCookieSize = 4 * 1024;

sub import {
    my $class = shift;
    my $pkg   = caller(0);
    no strict 'refs';
    *{"$pkg\::send_http_header"} = \&send_http_header;
}

sub send_http_header {
    my $self = shift;
    $self->manager->set_session($self, $self->session) if $self->session;
    $self->r->send_http_header(@_);
}

sub get_session {
    my($self, $page) = @_;

    # If there is no session, it constructs fresh one
    my $config = $page->create_config;
    my %jar    = CGI::Cookie->fetch;
    my $cookie = $jar{$config->cookie_name};
    my $data   = $cookie ? $self->_deserialize($self->key($config), $cookie->value) : undef;
    my $session = Sledge::Session::Cookie->new($data);

    # XXX: doesn't store time and URL
    # $session->param(_timestamp => time);
    # $session->param(_url       => $page->current_url);
    return $session;
}

sub key {
    my($self, $config) = @_;
    my $key = eval { $config->cookie_store_key };
    return $key ? (pack "H16", $key) : undef;
}

sub set_session {
    my($self, $page, $session) = @_;
    my $config = $page->create_config;
    my %data = map { $_ => scalar $session->param($_) } $session->param;
    my %options = (
	-name   => $config->cookie_name,
        -value  => $self->_serialize($self->key($config), \%data),
        -path   => $config->cookie_path,
    );
    $options{'-domain'} = $config->cookie_domain if $config->cookie_domain;
    $options{'-secure'} = 1 if eval {$config->cookie_secure};

    my $cookie = CGI::Cookie->new(%options);
    my $string = $cookie->as_string;
    if ((my $size = length($string)) >= $MaxCookieSize) {
	warn "encoded session size is $size, more then $MaxCookieSize!";
    }
    $page->r->headers_out->add('Set-Cookie' => $string);
}

sub _serialize {
    my($self, $key, $data) = @_;
    my $raw = MIME::Base64::encode(Storable::freeze($data));
    return $key ? Crypt::CBC->new($key, 'Blowfish')->encrypt_hex($raw) : $raw;
}

sub _deserialize {
    my($self, $key, $raw) = @_;
    my $data = $key ? Crypt::CBC->new($key, 'Blowfish')->decrypt_hex($raw) : $raw;
    my $decoded = eval { Storable::thaw(MIME::Base64::decode($data)) };
    if ($@) {
	Sledge::Exception::StorableSigMismatch->throw($@);
    }
    return $decoded;
}

package Sledge::Session::Cookie;
use base qw(Sledge::Session);

sub new {
    my($class, $data) = @_;
    $data->{_sid} ||= $class->_gen_session_id;
    bless {
	_sid => $data->{_sid},
	_data => $data,
    }, $class;
}

sub expire { }

sub cleanup { }

sub DESTROY { }

1;
__END__

=head1 NAME

Sledge::SessionManager::CookieStore - Store session in Cookie

=head1 SYNOPSIS

  package Your::Pages;
  use Sledge::SessionManager::CookieStore;

  sub create_manager {
      my $self = shift;
      return Sledge::SessionManager::CookieStore->new($self);
  }

  # you don't need create_session(), so comment it out!
  # sub create_session { ... }

  package Your::Config;
  # if your data should be secure
  $C{COOKIE_STORE_KEY} = 'key_for_cbc_encryption';
  $C{COOKIE_SECURE}    = 1;

=head1 DESCRIPTION

Sledge::SessionManager::CookieStore は SessionManager として利用でき、
セッションの中身をCookieに書き込みます。

=head1 CONFIGURATION

=over 4

=item COOKIE_STORE_KEY

  $C{COOKIE_STORE_KEY} = 'key_for_cbc_encryption';

Cookie データを CBC アルゴリズムで可逆暗号化します。C<COOKIE_STORE_KEY> で指定したキーを暗号化のキーとして利用します。デフォルトでは暗号化しません(Storable + Base64)。

=item COOKIE_SECURE

  $C{COOKIE_SECURE}    = 1;

Cookie に Secure フラグをつけます。デフォルトはつけません。

=back

=head1 AUTHOR

Tatsuhiko Miyagawa with Sledge development team.

=head1 SEE ALSO

L<Storable>, L<MIME::Base64>, L<Crypt::CBC>, L<Crypt::Blowfish>

=cut
