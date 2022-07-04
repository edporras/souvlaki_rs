# frozen_string_literal: true

require 'edn'
require_relative 'log'

module SouvlakiRS
  module Config
    PATH = ENV['HOME']
    FILE = File.join(PATH, '.souvlaki_rs') # file in EDN format

    def self.exist?
      File.exist? FILE
    end

    def self.list_program_codes
      pc = SouvlakiRS::Config.get_program_info
      warn 'Configured code List:'
      pc.each_pair { |code, data| warn " #{code}\t-\t'#{data[:pub_title]}'" }
    end

    def self.get_host_info(host)
      return get_entry(host) if exist?

      nil
    end

    def self.get_program_info(code = nil)
      if exist?
        progs = get_entry(:programs)

        if progs
          return progs if code.nil?

          return progs[code] if progs.key?(code)
        end
      end
      nil
    end

    # will cache config data
    @@data = nil

    def self.get_entry(e)
      if @@data.nil?
        return nil unless exist?

        # read contents
        File.open(FILE) do |file|
          @@data = EDN::read(file)
        end
      end

      return @@data[e] if @@data&.key?(e)

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
