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
3. Run `./scrape-cassini.pl`
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
images near the end of 2013 (images before this will be in the PDS),
and run up to a little higher than present count at time of writing.

Images that don't exist on the server will be skipped, and retried
next time. This has two implications:

1. Sometime relatively soon, images will arrive outside the configured
   range, and it will stop noticing new images.  This will be fixed
   with a smarter detection routing before that happens (otherwise
   just change the numbers at the top of the loop).

2. There are some gaps in image numbers; these will be re-attempted
   each time.

Try not to run it too often and annoy the NASA admins.

## Output

The TSV file has the following fields, 

* `id` The id=nnnn part of the image catalog page
* `file` The image filename on the Cassini server.  W/N in the first
  character indicates Wide/Narrow camera.
* `taken` The date the image was taken
* `taken-unix` .. as a unix timestamp
* `recvd` The date the image was received on Earth
* `recvd-unix` .. as a unix timestamp
* `target` The name of the target the camera was pointing at.
* `range-km` The range to target, in km (may be 0)
* `filter1` The first filter used.
* `filter2` The secont filter used.
* `image-url` The image download url.
* `download-as` The filename it will be save as, encoding the above fields.

There's a sample in the repo to look at.

## Issues

Please raise any issues here on GitHub.
