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

## Getting Started

The program is a perl script with dependency on a few libraries.

Steps:

1. Clone this repository
2. Install perl module dependencies
3. Run `./scrape-cassini.pl`
4. Lose your day browsing images.

On Ubuntu, the following should install the needed deps:

```
apt-get install libanyevent-http-perl libdatetime-format-natural-perl liburi-perl libjson-perl
```

Also recommended but not critical: `libev-perl libjson-xs-perl`

On other systems, similar package tools should provide what's needed,
although the names of the packages will vary by platform and packaging system.

Otherwise use `CPAN` or `CPANM`, with the native perl module names:
```
cpanm AnyEvent
cpanm AnyEvent::HTTP
cpanm DateTime::Format::Natural
cpanm URI
cpanm JSON
```

Note: I'm advised you may need `--force` for the `AnyEvent` module, 
at least on Windows; I have not yet looked into why.

## Running

Once the dependencies are installed, you can just run
`./scrape-cassini.pl`.

The program produces relatively little output by default:

 * a status summary every 20s like
```
2016-05-04 13:38:53.438688 +1000 note  main: In 60 s: 22 pages, 17 new images, 17 downloaded, 0 to download.
```

 * a save total every 5 mins (and on exit via `^C`)
```
2016-05-04 13:46:08.680355 +1000 note  main: Saving metadata: 27650 known images
```

### Verbosity

You can add several levels of verbosity (`--verbose`, `-v`) for
 * **info** about images as they are found and downloaded (`-v`)
 * **debug** messages about metadata contents and HTTP response codes (`-vv`)
 * **trace** each outgoing HTTP request (`-vvv`)

You can also obtain some quietitude using (`--quiet`, `-q`) to suppress
notes and even warnings and errors (with more), if you want.

### Tweaking and Load

The site chunks index metadata into 'pages' of 48 entries each.
The script defaults to fetching 50 index pages (x 48 = 2,400 images).

New images will be auto-detected on each run, but only within the
range of pages it fetches.

If you run it regularly, you probably don't need to fetch this many
pages every time, especially if you're just checking to see if there
are any new images.
On some days, many images are added, and this may not be enough
even if it has been run fairly regularly.  You may have gaps if the
indexer doesn't go back far enough.

If you want to change this range you can use `--pages` (or `-p`). Some
suggested values:

 * `-p 1` to quickly check whether there are any new images, and then
   re-run with a higher number to catch the extras if there were new
   ones.  Sometimes they arrive out of order, so 2-4 might be better
   than just 1.

 * `-p 20` if running a few times a day as images are being added, or
   after the above detects new images.

 * `-p 100` if it's been some time since you last ran it, or you
   suspect you have some data gaps because you interrupted it before
   it completed last time.

 * `-p 500` to go back about a year (images before this will be in the
   PDS).

As it runs, you can watch the status updates. If you get to a point
where additional index pages are not discovering new images, you can
safely interrupt it with `^C`. If you're still getting images
downloaded at the end of the run, you might want to run again with
more pages, as you probably have a gap.

This will all hopefully get smarter in future (some ideas in #2).

Try not to run it too often and annoy the NASA admins.

### Output

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
* `filter2` The second filter used.
* `image-url` The image download url.
* `download-as` The filename it will be save as, encoding the above fields.

There's a sample in the repo to look at.


## History

This program was originally written for an earlier, much less
user-friendly version of the site, where it literally had to scrape
metadata from the HTML text.

For casual use, browsing, filtering by (say) target and download of
selective images, the new site is much better.

This grabber now uses the JSON data that drives the new site, but
preserves the metadata TSV format and filename-encoding for continuity
with data fetched using the original.


## Issues

Please raise any issues here on GitHub.
