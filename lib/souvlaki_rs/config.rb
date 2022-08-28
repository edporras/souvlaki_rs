# frozen_string_literal: true

require 'edn'

module SouvlakiRS
  # config methods
  class Config
    attr_reader :config

    def initialize(config_path)
      File.open(config_path) do |file|
        @config = EDN.read(file)
      end
    end

    def get_host_info(host)
      val = get_entry(host)
      return val unless val.nil?

      raise "No configuration exists for #{host}"
    end

    def get_program_info(code = nil)
      progs = get_entry(:programs)
      return progs if code.nil?

      return nil unless progs.key?(code)

      info = progs[code]
      info[:code] = code
      info
    end

    private

    def get_entry(entry)
      return config[entry] if config.key?(entry)

      raise "Unknown config entry #{entry}"
    end
  end
end
