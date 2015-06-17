#!/usr/bin/perl

use common::sense;
use AnyEvent;
use AnyEvent::HTTP;
use URI;

$AnyEvent::HTTP::MAX_PER_HOST=8;
my $cv = AE::cv;
my $cvint = AE::signal INT => sub {$cv->send};

my %results;

my $fn = 'output.tsv';
my $page = 'http://saturn.jpl.nasa.gov/photos/raw/rawimagedetails/index.cfm?imageID=';

my $savew = AE::timer(300, 300, sub { save(); export(); });
load();

$cv->begin;
for my $id (320000 .. 322000) {
    next if exists $results{$id};
    $cv->begin;
    http_request (
        GET => $page . $id,
        persistent => 1,
        sub {
            my ($body, $hdr) = @_;
            $cv->end;

            $hdr->{Status} == 200 or return AE::log warn => "%u %u", $hdr->{Status}, $id;

            my ($link) = $body =~ m/^\s+<strong><a href="(.+?)">Full-Res:/mc;
            my ($line) = $body =~ m/^\s+(\D\d+\.jpg was taken on.*?)</m;
            AE::log debug => $line;

            my ($file,$taken,$recvd) = $line =~ m/(\D\d+.jpg) was taken on (.+?) and received on Earth (.+?). The/;
            my ($target)             = $line =~ m/The camera was pointing toward ([[:upper:]\s-_]+)[ ,]/;
            my ($range)              = $line =~ m/\(([\d,]+) kilometers\) away/;
            my ($filter1, $filter2)  = $line =~ m/image was taken using the (\w+) and (\w+) filter/;

            my @parts = (
                $id,
                $file, $taken, $recvd,
                $target,
                $range,
                $filter1, $filter2,
                URI->new($link)->abs($page)->as_string);

            AE::log info => join ('|', @parts);

            $results{$id} = \@parts if $file;
        });
}
$cv->end;
$cv->wait;

save();
exit 0;

sub save {
    rename $fn, $fn.'.old';
    open my $fh, "> :encoding(UTF-8)", $fn
        or return AE::log warn => "Can't open $fn for output!";

    AE::log info => 'Saving. Stats: ' .  %results . " " .  keys %results;
    say $fh join("\t", qw(id file taken recvd target range-km filter1 filter2 image-url));
    for (sort keys %results) {
        say $fh join("\t", @{$results{$_}});
    }
}

sub load {
    return unless -f $fn;
    open my $fh, "< :encoding(UTF-8)", $fn or return;
    while (<$fh>) {
        chomp;
        my @line = split /\t/;
        next if $line[0] eq 'id';
        $results{$line[0]} = \@line;
    }
    AE::log info => 'Loaded. Stats: ' .  %results . " " .  keys %results;
}
