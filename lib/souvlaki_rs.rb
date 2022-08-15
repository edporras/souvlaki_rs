# frozen_string_literal: true

require 'souvlaki_rs/log'
require 'souvlaki_rs/airtime'
require 'souvlaki_rs/audioport'
require 'souvlaki_rs/basecamp'
require 'souvlaki_rs/config'
require 'souvlaki_rs/fetch'
require 'souvlaki_rs/mail'
require 'souvlaki_rs/tag'
require 'souvlaki_rs/util'
require 'version'

#
# SouvlakiRS module
module SouvlakiRS
  AIRTIME_CONFIG = Config.get_host_info(:libretime)
  TMP_DIR_PATH = File.join(AIRTIME_CONFIG[:install_root], 'tmp')

  # ------------------------------------------------------------------------
  # download and import the program's episode that matches the given
  # date. Post notification on basecamp
  #
  def self.audioport_download(program, date, show_name_uri)
    files = []
    show_dir = SouvlakiRS::Util.get_show_path(program)

    # ensure the destination directory exists
    if SouvlakiRS::Util.check_destination(show_dir)

      # spider audioport and download any files we find that match the date
      files = SouvlakiRS::Audioport.fetch_files(program, date, show_name_uri)

      if files.nil? || files.empty?
        SouvlakiRS.logger.warn "Unable to download '#{program}' dated #{date} from Audioport"
        return []
      end
    end

    files
  end

  # ------------------------------------------------------------------------
  # parse the given RSS feed, find the program's entry(ies) that
  # matches the given date, download and import. Post notification on
  # basecamp
  #
  def self.rss_download(program, rss_uri, date)
    files = []
    mp3_uri = SouvlakiRS::Fetch.find_rss_entry(rss_uri, date)

    if mp3_uri
      # we have the uri and the destination - fetch the audio file
      files = remote_file_download(program, mp3_uri)
    else
      SouvlakiRS.logger.error "Unable to find RSS entry in #{rss_uri} for '#{program}', date: #{date}"
    end

    files
  end

  # ------------------------------------------------------------------------
  # fetch the file pointed to by uri
  #
  def self.remote_file_download(program, uri)
    files = []
    show_dir = SouvlakiRS::Util.get_show_path(program)

    # determine a file destination and ensure the directory exists
    if SouvlakiRS::Util.check_destination(show_dir)
      mp3_dest = File.join(show_dir, File.basename(uri))

      # try to download
      if SouvlakiRS::Fetch.fetch_file(uri, mp3_dest)
        files << mp3_dest
      else
        SouvlakiRS.logger.error "Unable to download '#{program}' from #{uri}"
      end
    end

    files
  end
end
