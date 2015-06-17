#!/usr/bin/perl

use common::sense;
use AnyEvent;
use AnyEvent::HTTP;
use URI;

my $cv = AE::cv;
my %results;
my $page = 'http://saturn.jpl.nasa.gov/photos/raw/rawimagedetails/index.cfm?imageID=';

$AnyEvent::HTTP::MAX_PER_HOST=8;

$cv->begin;
for my $id (330000 .. 332787) {
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

open(my $out, '>', 'output.tsv') or die 'open';
say $out join("\t", qw(id file taken recvd target range-km filter1 filter2 image-url));
for (sort keys %results) {
    say $out join("\t", @{$results{$_}});
}
close $out;
