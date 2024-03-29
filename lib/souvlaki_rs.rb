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
  class Manager
    attr_reader :bc2, :config, :audioport, :airtime, :tmp_dir_path, :options

    def initialize(options)
      @options = options
      @config = Config.new(options[:config])
      @airtime = Airtime.new(@config.get_host_info(:libretime))
      @bc2 = Basecamp2.new(@config.get_host_info(:basecamp)) if options[:post]
      @audioport = Audioport.new(@config.get_host_info(:audioport), File.join(@airtime.install_root, 'tmp'))
    end

    # ------------------------------------------------------------------------
    # fetch the file pointed to by uri
    #
    def remote_file_download(program)
      show_dir = get_program_path(program[:pub_title])

      # try to download
      mp3_dest = File.join(show_dir, File.basename(program[:file_url]))
      return mp3_dest if Fetch.fetch_file(program[:file_url], mp3_dest)

      program[:err_msg] = 'File not found'
      SouvlakiRS.logger.error " Unable to download '#{program[:pub_title]}' from #{program[:file_url]}"
      nil
    end

    # ------------------------------------------------------------------------
    # download and import the program's episode that matches the given
    # date. Post notification on basecamp
    #
    def audioport_download(program)
      # spider audioport and download any files we find that match the date
      files = audioport.fetch_files(program)
      SouvlakiRS.logger.warn "Unable to download '#{program[:pub_title]}' dated #{program[:pub_date]}" if files.empty?

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

      program[:file_url] = mp3_uri
      program[:origin] = program[:feed]

      # we have the uri and the destination - fetch the audio file
      files = []
      files << remote_file_download(program)
      files
    end

    #
    # call the corresponding method based on the source
    def fetch_files(program)
      case program[:source]
      when :file
        files = []
        f = remote_file_download(program)
        files << f unless f.nil?
        files
      when :audioport
        audioport_download(program)
      when :rss
        rss_download(program)
      else
        []
      end
    end

    #
    # retag the file
    # - album is always set to program name (for consistency).
    # - artist (creator) is set if none is in the file
    def retag_file(program, file)
      orig_tags = Tag.audio_file_read_tags(file)

      if options[:write_tags]
        tags = Tag.normalize(orig_tags, program)

        Tag.audio_file_write_tags(file, tags)
        return tags
      end

      SouvlakiRS.logger.info("Tags not rewritten. Read from file: Artist: '#{orig_tags[:artist]}', " \
                             "Album: '#{orig_tags[:album]}', Title: '#{orig_tags[:title]}'")
      orig_tags
    end

    #
    # import to libretime or fake it
    def import_file(file)
      if options[:import]
        status = airtime.import(file)
        SouvlakiRS.logger.info "Airtime import '#{file}', status: #{status}"
        return status
      end

      SouvlakiRS.logger.warn "NOOP run - will not import #{file} - deleting"
      FileUtils.rm_f(file)
      true
    end

    #
    # this handles processing fetch the corresponding program's file(s)
    def process_program(program)
      files = fetch_files(program)
      if files.empty?
        bc2&.register_error(program)
        return
      end

      # tag, import, notify handling
      files.each_with_index do |file, idx|
        program[:html_title] = program[:html_titles][idx] if program[:html_titles]
        program[:tags] = retag_file(program, file)
        next unless import_file(file) && bc2

        program[:d_hms] = Program.file_duration(program) if program.key?(:block_len)
        bc2.register_ok(program)
      end
    end

    #
    # process the list of parsed codes
    def process_codes(codes)
      codes = valid_codes(codes)
      return false if codes.nil?

      program_configs = codes_to_configs(codes)
      program_configs.each do |program|
        SouvlakiRS.logger.info "Request for #{program[:pub_title]} dated #{program[:pub_date]}, source: #{program[:source]}"
        process_program(program)
      end

      bc2&.post_comment
    end

    #
    # returns the list of validated and prepped program configs
    def codes_to_configs(program_codes)
      program_codes.map { |code| config.get_program_info(code) }
                   .select { |prog| Program.valid?(prog) }
                   .map { |prog| Program.prepare(prog, options) }
    end

    #
    # returns the list of valid codes (initial check to validate arguments)
    def valid_codes(codes)
      program_codes = config.get_program_info
      checked_codes = codes.uniq.map(&:to_sym).group_by { |c| program_codes.key?(c) ? :ok : :unknown }

      SouvlakiRS.logger.warn("Skipping unrecognized codes #{checked_codes[:unknown]}") unless
        checked_codes[:unknown].nil?

      checked_codes[:ok]
    end

    #
    # joins libretime's install path with a subfolder for copying files to
    def get_program_path(name)
      path = File.join(airtime.install_root, 'tmp', name)
      Util.ensure(path)
    end
  end
end
