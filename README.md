Souvlaki Radio Station
======================

A set of scripts for automating file fetching and importing of
syndicated audio files for WGOT-LP 94.7FM in Gainesville, FL. This
won't likely be very useful to people since it fits our very specific
needs:

* Running Sourcefabric's
  [Airtime](https://www.sourcefabric.org/en/airtime/) for broadcast of
  our signal
* Airing of local and various syndicated programs from a variety of
  sources (RSS, [AudioPort](http://audioport.org/), self-hosted)
* Use of [Basecamp 2](https://basecamp.com/) for WGOT-LP member
  and supporter communication

This gem is installed on a linux system we manage and the fetching
scripts are scheduled using
[cron](https://en.wikipedia.org/wiki/Cron). The configuration file is
written in [EDN](https://github.com/edn-format/edn), a sample of which
is included in the source.

The script is run with one or more codes specified in the
configuration file representing various sources. If files are fetched,
a notification is posted to a specific thread on a Basecamp project
we use to coordinate scheduling.

The name is based on the wonderful song by Slowdive from their
[Souvlaki](https://en.wikipedia.org/wiki/Souvlaki_(album)) release.

## Installation

```sh
sudo rmdir /srv/airtime/bin
sudo cp bin/libretime-import /srv/airtime/bin
sudo chown -R www-data:www-data /srv/airtime/bin
```

You can add the bin folder to your path so you can easily find the
`srs_fetch` script. Alternatively, if you have a ruby dev environment,
build and install a local gem:

```sh
gem install bundler
bundle install
gem build souvlaki_rs
gem install souvlaki_rs-*.gem
```
