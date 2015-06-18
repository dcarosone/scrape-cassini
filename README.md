# Cassini Raw Image grabber

This is a metadata scraper and downloader for Cassini raw images,
inspired by
[a request from Emily Lakdawalla on Twitter](https://twitter.com/elakdawalla/status/611023205155799040)

## Overview

The program scrapes image metadata from the
[Cassini Raw Images library](http://saturn.jpl.nasa.gov/photos/raw/)
and collects it in a Tab-Separated file `output.tsv`.

When images are found, they are scheduled for download (if they don't
already exist).  Downloaded filenames encode most of the image
metadata:

`YYYYMMDD.OriginalName.Target.Filter1.Filter2.RangeKM.jpg`

Not all images have range data, so this may be 0.

The TSV file is saved every 5 minutes while running, and at program
exit.  It's reloaded on startup, so the idea is that the program can
be run at any time, stopped at any time, and will resume where it left
off.  If anything needs to be re-fetched, just delete the row from the
TSV, or delete the image file.

## Running

The program is a perl script with dependency on a few libraries.

Steps:
1. Clone this repository
2. Install perl module dependencies
3. Run ./scrape-cassini.pl
4. Lose your day browsing images.

On Ubuntu, the following should install the needed deps:

```
apt-get install libanyevent-perl libanyevent-http-perl libdatetime-format-natural-perl liburi-perl
```

Also recommended but not critical: `libev-perl`

On other systems, similar package tools should provide what's needed,
othewise use `CPAN`.

## Scheduling

All requests are scheduled in a queue; this has the effect that the
first time it's run, it will spend a long time fetching metadata
before any image downloads reach the front of the queue.

If you want to see some images, let it run for a while, interrupt it
with ^C, and start it again.  This will queue downloads for the images
already known before looking for more.

## Tweaking and Load

At present, the image numbers to fetch are hard-coded. They start at
images near the end of 2013, and run up to a little higher than
present count at time of writing.

Images that don't exist on the server will be skipped, and retried
next time. This has two implications:

1. Sometime relatively soon, images will arrive outside the configured
   range, and it will stop noticing new images.  This will be fixed
   with a smarter detection routing before that happens (otherwise
   just change the numbers at the top of the loop).

2. There are some gaps in image numbers; these will be re-attempted
   each time.

## Output

The TSV file has the following format:

id | file | taken | taken-unix | recvd | recvd-unix | target | range-km | filter1 | filter2 | image-url | download-as
-- | ---- | ----- | ---------- | ----- | ---------- | ------ | -------- | ------- | ------- | --------- | -----------
300000 | N00217467.jpg | 20131015 | 1381795200 | 20131016 | 1381881600 | TITAN | 558487 | CL1 | CB3 | http://saturn.jpl.nasa.gov/multimedia/images/raw/casJPGFullS80/N00217467.jpg | 20131015.N00217467.TITAN.CL1.CB3.558487.jpg
300001 | N00217468.jpg | 20131015 | 1381795200 | 20131016 | 1381881600 | TITAN | 558775 | CL1 | CB3 | http://saturn.jpl.nasa.gov/multimedia/images/raw/casJPGFullS80/N00217468.jpg | 20131015.N00217468.TITAN.CL1.CB3.558775.jpg
300002 | N00217469.jpg | 20131015 | 1381795200 | 20131016 | 1381881600 | TITAN | 559352 | CL1 | CB3 | http://saturn.jpl.nasa.gov/multimedia/images/raw/casJPGFullS80/N00217469.jpg | 20131015.N00217469.TITAN.CL1.CB3.559352.jpg
300003 | N00217470.jpg | 20131015 | 1381795200 | 20131016 | 1381881600 | TITAN | 

## Issues

Please raise any issues here on GitHub.
