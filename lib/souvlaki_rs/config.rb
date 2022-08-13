# frozen_string_literal: true

require 'edn'
require_relative 'log'
require_relative 'tag'

module SouvlakiRS
  # config methods
  module Config
    FILE = File.join(Dir.home, '.souvlaki_rs') # file in EDN format

    def self.list_program_codes
      pc = SouvlakiRS::Config.get_program_info
      warn 'Configured code List:'
      pc.each_pair { |code, data| warn " #{code}\t-\t'#{data[:pub_title]}'" }
    end

    def self.get_host_info(host)
      val = get_entry(host) if exist?
      return val unless val.nil?

      raise "No configuration exists for #{host}"
    end

    def self.validate_program_config(program_config)
      genre = program_config[:genre]
      raise "Unknown genre #{genre} for program code #{code}" if genre && Tag::GENRES[genre].nil?

      program_config
    end

    def self.get_program_info(code = nil)
      if exist?
        progs = get_entry(:programs)

        if progs
          return progs if code.nil?

          return validate_program_config(progs[code])
        end
      end
      nil
    end

    # will cache config data
    @@data = nil
    def self.get_entry(entry)
      if @@data.nil?
        return nil unless exist?

        # read contents
        File.open(FILE) do |file|
          @@data = EDN.read(file)
        end
      end

      return @@data[entry] if @@data&.key?(entry)

      nil
    end

    def self.exist?
      unless File.exist? FILE
        warn "Configuration file not found. See config.example and save it as #{FILE} once set up for your needs."
        exit
      end
      true
    end
  end
end
