package Banjaai::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::RouterBoom;
use LWP::UserAgent;
use Time::Piece;
use Text::Xslate qw( mark_raw );
use URI::Escape;

my $protocol = 'http://';
my $domain = 'jbbs.shitaraba.net';

## AA 関係の板一覧をトップページに表示
any '/' => sub {
    my ($c) = @_;
    my @board_list = (
        'sports/3246',   # ギコ連合板＠地下スレ
        'otaku/12973',   # やる夫板II
        'otaku/15956',   # やる夫スレヒロイン板（新）
        'otaku/14429',   # やらない夫板II
        'otaku/14504',   # 小さなやる夫板
        'otaku/16195',   # 辺境にあるやる夫板
        'otaku/15257',   # やる夫板ＥＸ
        'otaku/12368',   # やる夫系雑談・避難・投下板（やる夫板）
        'internet/3408', # やる夫系雑談・避難・投下板（緊急避難用）
    );
    my @boards = ();

    for my $board (@board_list) {
        my $setting = get_board_settings($board);
        push @boards, $setting;
    }

    return $c->render('index.tx', {
        boards => \@boards,
        page_title => 'Banjaai',
        page_description => mark_raw('<h2 style="padding: 30px; text-align: center; line-height: 1; letter-spacing: -2px;">AA 対応したらば Viewer</h2>')
    });
};

## 板内のスレ一覧を表示
get '{category:[a-z]+}/{board_id:[0-9]+}' => sub {
    my ($c, $args) = @_;
    my $ua = LWP::UserAgent->new;
    my ($category, $board_id) = ($args->{category}, $args->{board_id});

    my $server_endpoint = $protocol . $domain . '/' . $category . '/' . $board_id . '/subject.txt';
    my $req = HTTP::Request->new(GET => $server_endpoint);
    my $resp = $ua->request($req);

    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        Encode::from_to($message, 'eucjp', 'utf8');
        my @subjects = split("\n", $message);
        my @threads = ();
        for my $subject (@subjects) {
            my @id_title = split('.cgi,', $subject);
            my $thread = {
                id => $id_title[0],
                created_datetime =>localtime($id_title[0])->datetime,
                url => $category . '/' . $board_id . '/' . $id_title[0],
                title => $id_title[1],
            };

            push @threads, $thread;
        }

        my $board_setting = get_board_settings($category . '/' . $board_id);
        return $c->render('index.tx', {
            threads => \@threads,
            page_title => $board_setting->{title},
            title => $board_setting->{title} . " | Banjaai",
        });

    }
};

## スレの表示
get '{category:[a-z]+}/{board_id:[0-9]+}/{id:[0-9]+}' => sub {
    my ($c, $args) = @_;
    my ($category, $board_id, $id) = ($args->{category}, $args->{board_id}, $args->{id});

    my @contents = ();
    my $server_endpoint = $protocol . $domain . '/bbs/rawmode.cgi/' . $category . '/' . $board_id . '/' . $id;

    @contents = dat2hash($server_endpoint);
    my $thread_name = pop @contents;
    return $c->render('thread.tx', {
        thread_name => $thread_name,
        thread => \@contents,
        title => $thread_name . " | Banjaai"
    });
};

## スレの表示（レス範囲指定付き）
get '{category:[a-z]+}/{board_id:[0-9]+}/{id:[0-9]+}/{range:[0-9n\-]+}' => sub {
    my ($c, $args) = @_;
    my ($category, $board_id, $id, $range) = ($args->{category}, $args->{board_id}, $args->{id}, $args->{range});

    my @contents = ();
    my $server_endpoint = $protocol . $domain . '/bbs/rawmode.cgi/' . $category . '/' . $board_id . '/' . $id . '/' . $range;

    @contents = dat2hash($server_endpoint);
    my $thread_name = pop @contents;
    return $c->render('thread.tx', {
        thread_name => $thread_name,
        thread => \@contents,
        title => $thread_name . " | Banjaai"
    });
};

get 'ua' => sub {
    my ($c) = @_;
    my $ua = $c->req->headers->user_agent;
    return $c->render('index.tx', {
        ua => $ua,
    });
};

get 'bbs/read.cgi/{category:[a-z]+}/{board_id:[0-9]+}/{id:[0-9]+}' => sub {
    my ($c, $args) = @_;
    my ($category, $board_id, $id) = ($args->{category}, $args->{board_id}, $args->{id});
    my $redirect_path = '/' . $category . '/' . $board_id . '/' . $id;
    return $c->redirect($redirect_path);
};

get 'bbs/read.cgi/{category:[a-z]+}/{board_id:[0-9]+}/{id:[0-9]+}/{range:[0-9n\-]+}' => sub {
    my ($c, $args) = @_;
    my ($category, $board_id, $id, $range) = ($args->{category}, $args->{board_id}, $args->{id}, $args->{range});
    my $redirect_path = '/' . $category . '/' . $board_id . '/' . $id . '/' . $range;
    return $c->redirect($redirect_path);
};

sub dat2hash {
    my ($server_endpoint) = @_;
    my @contents = ();
    my $thread_name =  '';

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $server_endpoint);
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        Encode::encode 'utf8', $message;
        my @thread = split("\n", $message);
        my @thread_0 = split('<>', $thread[0]);
        $thread_name = $thread_0[5];

        for my $responce (@thread) {
            my @elements = split('<>', $responce);
            $elements[1] =~ s/\<\/?b\>//g;
            my $res_container = {
                num => $elements[0],
                name => mark_raw($elements[1]),
                mailto => $elements[2],
                time => $elements[3],
                user_id => $elements[6],
                html => mark_raw($elements[4]),
            };
            push @contents, $res_container;
        }
    }
    return @contents, $thread_name;
}

sub get_board_settings {
    my ($board) = @_;
    my $ua = LWP::UserAgent->new;

    my $server_endpoint = $protocol . $domain . '/bbs/api/setting.cgi/' . $board . '/';
    my $req = HTTP::Request->new(GET => $server_endpoint);
    my $resp = $ua->request($req);

    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        Encode::encode 'utf8', $message;
        my @settings = split("\n", $message);
        my $setting = {
            url => $board,
            title => substr($settings[8], 10),
        };
        return $setting;
    }
}

1;
