#!/usr/bin/perl

use common::sense;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Log;
use JSON;
use URI;
use DateTime::Format::Natural;
my $date_parser = DateTime::Format::Natural->new();

my $verbose = 6;
my $pagelimit = 50;
use Getopt::Long;
Getopt::Long::Configure ("bundling");
GetOptions(
    'verbose|v' => sub {$verbose++},
    'quiet|q'   => sub {$verbose--},
    'pages|p=i' => \$pagelimit
    );

$AnyEvent::HTTP::MAX_PER_HOST=8;
$AnyEvent::Log::FILTER->level ($verbose);

my $fn = 'output.tsv';
my $cv = AE::cv;

my %results;
load();
my $savew = AE::timer  300, 300, sub {save()};
my $cvint = AE::signal INT => sub {$cv->send};

my %stats = (pages => 0, todownload => 0, new => 0, downloaded => 0, start => AE::now);
my $statw = AE::timer 20, 20, sub {
    AE::log note =>
        'In %d s: %d pages, %d new images, %d downloaded, %d to download.',
        AE::now - $stats{start}, @stats{qw{pages new downloaded todownload}};
};

$cv->begin;

if (scalar %results) {
    my $count;
    $count += download($_) for keys %results;
    AE::log note => "Queued %d downloads of previously-known images..", $count if $count;
}

getpage() for (1 .. 3);
$cv->wait;
save();
exit 0;

sub getpage {
    state $nextpage = 0;
    my $page = ++$nextpage;
    return unless $page <= $pagelimit;
    fetch("http://saturnraw.jpl.nasa.gov/cassiniapi/raw/?page=$page", sub {
        my $d = decode_json(shift);
        for (@{$d->{DATA}}) {
            my %i = %$_;
            my @parts = (
                $i{feiimageid}, $i{filename},                        # 0, 1
                date_fmt($i{observeDate}), date_fmt($i{earthDate}),  # 2, 3, 4, 5 (2 each)
                target_fmt($i{target}),                              # 6
                range_fmt($i{range_km}),                             # 7
                $i{filter1}, $i{filter2},                            # 8, 9
                URI->new($i{full})->abs('http://saturnraw.jpl.nasa.gov')->as_string); # 10
            my $download_as = join('.', $parts[2], $parts[1] =~ /^(\w+).jpg/, @parts[6,8,9,7], 'jpg');
            push @parts, $download_as;                   # 11
            AE::log debug => join ('|', @parts);
            my $id = $i{feiimageid};
            AE::log info  => 'found new image %s (of %d)', $id, ++$stats{new} unless exists $results{$id};
            $results{$id} = \@parts;
            download($id);
        };
        ++$stats{pages};
        AE::postpone {getpage()};
        $cv->end if $page == $pagelimit;
    });
};

sub fetch {
    my ($url, $cb) = @_;
    AE::log trace => "fetch: $url";
    $cv->begin;
    http_request (GET => $url, persistent => 1, sub {
        my ($body, $hdr) = @_;
        AE::log debug => "http %u for GET %s", $hdr->{Status}, $url;
        $cv->end;
        $hdr->{Status} == 200 or return AE::log warn => "http %u for GET %u", $hdr->{Status}, $url;
        $cb->($body);
    });
};

sub download {
    my $id = shift;
    my ($url,$fn,$mtime) = @{$results{$id}}[10,11,3];

    $fn = 'images/'.$fn;
    return 0 if -f $fn;
    ++$stats{todownload};
    fetch($url, sub {
        my $body = shift;
        mkdir 'images' unless -d 'images';
        open my $fh, "> :raw", $fn
            or return AE::log warn => "Can't open $fn for output!";
        print $fh $body;
        close $fh;
        utime $mtime, $mtime, $fn;
        AE::log info => "downloaded %s", $fn;
        --$stats{todownload};
        ++$stats{downloaded};
    });
    return 1;
};

sub save {
    rename $fn, $fn.'.old' if -e $fn;
    open my $fh, "> :encoding(UTF-8)", $fn
        or return AE::log warn => "Can't open $fn for output!";

    AE::log note => 'Saving metadata: %d known images', scalar keys %results;
    say $fh join("\t", qw(id file taken taken-unix recvd recvd-unix target range-km filter1 filter2 image-url download-as));
    say $fh join("\t", @{$results{$_}}) for (sort keys %results);
    close $fh;
};

sub load {
    return unless -f $fn;
    open my $fh, "< :encoding(UTF-8)", $fn or return;
    while (<$fh>) {
        chomp;
        my @line = split /\t/;
        next if $line[0] eq 'id';
        $results{$line[0]} = \@line;
    }
    AE::log note => 'Loaded metadata: %d known images', scalar keys %results;
};

sub range_fmt {
    my $r = shift;
    $r =~ s/,//g;
    return $r+0;
};

sub date_fmt {
    my $ds = shift;
    my $dt = $date_parser->parse_datetime($ds);
    return ($dt->ymd(''), $dt->epoch()) if ($date_parser->success);
    AE::log warn => "date conversion failed for %s", $ds;
    return ($ds,undef);
};

sub target_fmt {
    my $t = shift;
    $t =~ s/ /-/g;
    return $t;
};
