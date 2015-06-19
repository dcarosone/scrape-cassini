#!/usr/bin/perl

use common::sense;
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Log;
use URI;
use DateTime::Format::Natural;
my $date_parser = DateTime::Format::Natural->new();

$AnyEvent::HTTP::MAX_PER_HOST=8;
$AnyEvent::Log::FILTER->level ("info");

my $fn = 'output.tsv';
my $page = 'http://saturn.jpl.nasa.gov/photos/raw/rawimagedetails/index.cfm?imageID=';
my $cv = AE::cv;

my %results;
load();
my $savew = AE::timer  300, 300, sub {save()};
my $cvint = AE::signal INT => sub {$cv->send};


$cv->begin;

if (scalar %results) {
    my $count;
    $count += download($_) for keys %results;
    AE::log note => "Queued %d downloads of previously known images..", $count if $count;
}

AE::log note => "Looking for latest image..";
fetch ('http://saturn.jpl.nasa.gov/photos/raw/?start=1', sub {
    my $body = shift;
    my ($max) = $body =~ m{^\s+<a href="rawimagedetails/index.cfm\?imageID=(\d+)">}m;
    AE::log note => "Found max image id: %d", $max;
    return unless $max;
    get_metadata($_) for (302919 .. $max); # 1st image of 2014
    $cv->end;
});

$cv->wait;
save();
exit 0;


sub get_metadata {
    my $id = shift;
    return if exists $results{$id};
    fetch ($page . $id, sub {
        my $body = shift;
        my ($link) = $body =~ m/^\s+<strong><a href="(.+?)">Full-Res:/mc;
        my ($line) = $body =~ m/^\s+(\D\d+\.jpg was taken on.*?)</m;
        AE::log debug => $line;

        my ($file,$taken,$recvd) = $line =~ m/(\D\d+.jpg) was taken on (.+?) and received on Earth (.+?). The/;
        my ($target)             = $line =~ m/The camera was pointing toward ([[:upper:]\s-_]+)[ ,]/;
        my ($range)              = $line =~ m/\(([\d,]+) kilometers\) away/;
        my ($filter1, $filter2)  = $line =~ m/image was taken using the (\w+) and (\w+) filter/;

        return unless $file;

        my @parts = (
            $id, $file,                              # 0, 1
            date_fmt($taken), date_fmt($recvd),      # 2, 3, 4, 5 (2 each)
            target_fmt($target),                     # 6
            range_fmt($range),                       # 7
            $filter1, $filter2,                      # 8, 9
                URI->new($link)->abs($page)->as_string); # 10
        my $download_as = join('.', $parts[2], $parts[1] =~ /^(\w+).jpg/, @parts[6,8,9,7], 'jpg');
        push @parts, $download_as;                   # 11

        AE::log info => join ('|', @parts);

        $results{$id} = \@parts;
        download($id);
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
    fetch($url, sub {
        my $body = shift;
        mkdir 'images' unless -d 'images';
        open my $fh, ">", $fn
            or return AE::log warn => "Can't open $fn for output!";
        print $fh $body;
        close $fh;
        utime $mtime, $mtime, $fn;
        AE::log info => "download %s from %s", $fn, $url;
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
