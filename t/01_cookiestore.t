use strict;
use Test::More 'no_plan';

use lib 't/lib';

package Mock::Pages;
use base qw(Sledge::TestPages);
use Sledge::SessionManager::CookieStore;

use vars qw($TMPL_PATH $COOKIE_NAME $COOKIE_STORE_KEY);
$TMPL_PATH = "t/view";
$COOKIE_NAME = 'sid';

sub create_manager {
    my $self = shift;
    return Sledge::SessionManager::CookieStore->new($self);
}

sub dispatch_foo {
    my $self = shift;
    $self->session->param(name => 'miyagawa');
    $self->tmpl->param(session => $self->session);
}

sub dispatch_bar { }

package main;


for my $key ('', 'fooo') {
    local $ENV{HTTP_COOKIE};
    local $Mock::Pages::COOKIE_STORE_KEY = $key;

    my $sid;

    # test first session
    {
	my $p = Mock::Pages->new;
	$p->dispatch('foo');

	my $out = $p->output;
	like $out, qr/miyagawa/, 'miyagawa';

	my $cookie = ($out =~ /Set-Cookie: (.*?); path=/)[0];
	ok(length($cookie) > 0);

	$sid = ($out =~ /session_id: (.*)/)[0];
	$ENV{HTTP_COOKIE} = $cookie;
    }

    {
	my $p = Mock::Pages->new;
	$p->dispatch('bar');

	my $out = $p->output;
	like $out, qr/miyagawa/, 'miyagawa again';

	my $sid2 = ($out =~ /session_id: (.*)/)[0];
	is $sid, $sid2;
    }
}



