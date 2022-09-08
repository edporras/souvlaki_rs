# frozen_string_literal: true

require 'set'

module SouvlakiRS
  module Program
    #
    # preps the program data
    def self.prepare(program, options)
      program[:retitle] = true if program[:retitle].nil?
      program[:today] ||= false

      # unless configured to fetch today's show, fetch yesterday's
      program[:pub_date] = options[:req_date]
      if options[:date].nil? && !program[:today]
        program[:pub_date] -= 1
        SouvlakiRS.logger.info "Backdating pub date to yesterday (#{program[:pub_date]})"
      end

      case program[:source]
      when :file
        file_url = program[:base_url]
        file_url += "/#{program[:pub_date].strftime(program[:format])}" if program[:format]
        program[:file_url] = file_url
      end

      program
    end

    #
    # return the dureation of the program based on fields set by tags
    def self.file_duration(program)
      return nil unless program.key?(:block)

      block_len = program[:block]
      file_dur = program[:tags][:length] / 60.0
      min_len = block_len - (block_len / 5.0)
      return nil unless file_dur >= block_len || file_dur < min_len

      Time.at(program[:tags][:length]).utc.strftime('%H:%M:%S')
    end

    SOURCE_TYPES = Set.new(%i[file rss audioport])
    REQ_KEYS = Set.new(%i[pub_title creator name])

    #
    # checks that a program entry in the config is valid
    def self.valid?(program)
      REQ_KEYS.each do |k|
        if program[k].nil?
          SouvlakiRS.logger.error("Required field :#{k} missing for program code :#{program[:code]}")
          return false
        end
      end

      genre = program[:genre]
      if genre && Tag::GENRES[genre].nil?
        SouvlakiRS.logger.error("Unknown genre '#{genre}' for program code #{program[:code]}")
        return false
      end

      source = program[:source]
      unless SOURCE_TYPES === source
        SouvlakiRS.logger.error("Unknown :source type ':#{source}' for program code :#{program[:code]}")
        return false
      end

      case source
      when :file
        if program[:base_url].nil?
          SouvlakiRS.logger.error("No :base_url specified for program code :#{program[:code]}")
          return false
        end
      when :rss
        if program[:feed].nil?
          SouvlakiRS.logger.error("No :feed specified for progeam code :#{program[:code]}")
          return false
        end
      end

      true
    end
  end
end
