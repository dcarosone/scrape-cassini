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

You can just run `./scrape-cassini.pl`.  The program produces
relatively little output by default:

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

The script is wired to fetch 500 index pages (x 48 = 24,000 images).
This will go back about a year (images before this will be in the
PDS).

If you run it regularly, you probably don't need to fetch this many
pages every time.  This will hopefully get smarter in future.

If you want to change this range you can edit the line

```perl
    ($page < 500) ? AE::postpone {getpage()} : $cv->end;
```

New images will be auto-detected on each run.

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

## Issues

Please raise any issues here on GitHub.
