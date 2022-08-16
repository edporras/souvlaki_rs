# frozen_string_literal: true

require 'edn'
require_relative 'log'

module SouvlakiRS
  # config methods
  module Config
    FILE = File.join(Dir.home, '.souvlaki_rs') # file in EDN format

    def self.get_host_info(host)
      val = get_entry(host)
      return val unless val.nil?

      raise "No configuration exists for #{host}"
    end

    def self.get_program_info(code = nil)
      progs = get_entry(:programs)
      return progs if code.nil?

      info = progs[code]
      info[:code] = code
      info
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

      raise "Unknown config entry #{entry}"
    end

    def self.exist?
      unless File.exist? FILE
        warn "Configuration file not found. See config.example and save it as #{FILE} once set up for your needs."
        exit
      end
      true
    end

    def self.list_program_codes
      pc = get_program_info
      warn 'Configured code List:'
      pc.each_pair { |code, data| warn " #{code}\t-\t'#{data[:pub_title]}'" }
    end
  end
end
