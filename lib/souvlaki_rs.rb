# frozen_string_literal: true

require 'souvlaki_rs/log'
require 'souvlaki_rs/airtime'
require 'souvlaki_rs/audioport'
require 'souvlaki_rs/basecamp'
require 'souvlaki_rs/config'
require 'souvlaki_rs/fetch'
require 'souvlaki_rs/mail'
require 'souvlaki_rs/program'
require 'souvlaki_rs/tag'
require 'souvlaki_rs/util'
require 'version'

#
# SouvlakiRS module
module SouvlakiRS
  AIRTIME_CONFIG = Config.get_host_info(:libretime)
  TMP_DIR_PATH = File.join(AIRTIME_CONFIG[:install_root], 'tmp')

  class Manager
    def initialize(options)
      @options = options
      @bc = Basecamp::Comment.new if options[:post]
    end

    # ------------------------------------------------------------------------
    # fetch the file pointed to by uri
    #
    def remote_file_download(program)
      show_dir = Util.get_show_path(program[:pub_title])

      # determine a file destination and ensure the directory exists
      Util.check_destination(show_dir)

      # try to download
      mp3_dest = File.join(show_dir, File.basename(program[:file_url]))
      if Fetch.fetch_file(program[:file_url], mp3_dest)
        files = []
        files << mp3_dest
        return files
      end

      SouvlakiRS.logger.error "Unable to download '#{program[:pub_title]}' from #{program[:file_url]}"
      []
    end

    # ------------------------------------------------------------------------
    # download and import the program's episode that matches the given
    # date. Post notification on basecamp
    #
    def audioport_download(program)
      # ensure the destination directory exists
      show_dir = Util.get_show_path(program[:pub_title])
      Util.check_destination(show_dir)

      # spider audioport and download any files we find that match the date
      files = Audioport.fetch_files(program[:pub_title], program[:pub_date], program[:show_name_uri])

      if files.nil? || files.empty?
        SouvlakiRS.logger.warn "Unable to download '#{program[:pub_title]}' dated #{program[:pub_date]} from Audioport"
        return []
      end

      files
    end

    # ------------------------------------------------------------------------
    # parse the given RSS feed, find the program's entry(ies) that
    # matches the given date, download and import. Post notification on
    # basecamp
    #
    def rss_download(program)
      mp3_uri = Fetch.find_rss_entry(program[:feed], program[:pub_date])

      unless mp3_uri
        SouvlakiRS.logger.error "Unable to find RSS entry in #{program[:feed]} for '#{program[:pub_title]}', " \
                                "date: #{program[:pub_date]}"
        return []
      end

      # we have the uri and the destination - fetch the audio file
      program[:file_url] = mp3_uri
      remote_file_download(program)
    end

    #
    # call the corresponding method based on the source
    def fetch_files(program)
      case program[:source]
      when :file
        remote_file_download(program)
      when :audioport
        audioport_download(program)
      when :rss
        rss_download(program)
      else
        []
      end
    end

    #
    # register the text to post for the notification
    def update_notifications(program, files)
      files.each do
        next unless program[:imported]

        msg = program[:tags][:title]

        # report warning if duration info is given and program's looks odd
        if program.key?(:block)
          block_len = program[:block]
          min_len = block_len - (block_len / 5)
          file_dur = program[:tags][:length] / 60.0

          if file_dur >= block_len || file_dur < min_len
            d_hms = Time.at(program[:tags][:length]).utc.strftime('%H:%M:%S')
            msg << " (Length warning: #{d_hms})"
            SouvlakiRS.logger.warn "File duration (#{d_hms}) - block is #{block_len}"
          end
        end

        msg_id = program[:msg_id] if program.key?(:msg_id)
        @bc.add_text(msg, msg_id)
      end
    end

    #
    # this handles processing fetch the corresponding program's file(s)
    def process_program(program)
      SouvlakiRS.logger.info "Fetching #{program[:pub_title]} for #{program[:pub_date]}, source: #{program[:source]}"

      files = fetch_files(program)
      return false if files.empty?

      # tag & import handling
      files.each do |file|
        # retag:
        # - album is always set to program name (for consistency).
        # - artist (creator) is set if none is in the file
        orig_tags = Tag.audio_file_read_tags(file)
        retitle = program[:retitle].nil? || program[:retitle] != false
        tags = Tag.normalize_tags(orig_tags,
                                  def_album: program[:name],
                                  def_artist: program[:creator],
                                  def_genre: program[:genre],
                                  pub_date: program[:pub_date],
                                  rewrite_title: retitle)

        if @options[:write_tags]
          Tag.audio_file_write_tags(file, tags)
        else
          SouvlakiRS.logger.info("Tags not rewritten. Read from file: Artist: '#{orig_tags[:artist]}', " \
                                 "Album: '#{orig_tags[:album]}', Title: '#{orig_tags[:title]}'")
        end

        # import to airtime
        if @options[:import]
          program[:imported] = Airtime.import(file)
          SouvlakiRS.logger.info "Airtime import '#{file}', status: #{program[:imported]}"
        else
          SouvlakiRS.logger.warn "NOOP run - will not import #{file} - deleting"
          FileUtils.rm_f(file)
          program[:imported] = true
        end

        # save tags - TODO: only done for output. Rework to avoid this.
        program[:tags] = tags
      end

      # append to notification
      update_notifications(program, files) if @bc

      true
    end

    def process_codes(codes)
      program_configs = codes_to_configs(valid_codes(codes))
      program_configs.each { |program| process_program(program) }

      @bc&.post
    end

    #
    # returns the list of validated and prepped program configs
    def codes_to_configs(program_codes)
      program_codes.map { |code| Config.get_program_info(code) }
                   .select { |prog| Program.valid?(prog) }
                   .map { |prog| Program.prepare(prog, @options) }
    end

    #
    # returns the list of valid codes (initial check to validate arguments)
    def valid_codes(codes)
      program_codes = Config.get_program_info
      checked_codes = codes.uniq.map(&:to_sym).group_by { |c| program_codes.key?(c) ? :ok : :unknown }

      SouvlakiRS.logger.warn("Skipping unrecognized codes #{checked_codes[:unknown]}") unless
        checked_codes[:unknown].nil?

      checked_codes[:ok]
    end
  end
end
