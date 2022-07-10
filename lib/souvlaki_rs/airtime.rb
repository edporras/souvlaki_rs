# frozen_string_literal: true

module SouvlakiRS
  module Airtime
    AIRTIME_IMPORT_CMD = '/srv/airtime/bin/libretime-import'

    def self.import(file)
      if !File.exist?(AIRTIME_IMPORT_CMD) || !File.executable?(AIRTIME_IMPORT_CMD)
        SouvlakiRS.logger.error "Airtime import cmd #{AIRTIME_IMPORT_CMD} not found"
        return false
      end

      creds = SouvlakiRS::Config.get_host_info(:libretime)

      if system("#{AIRTIME_IMPORT_CMD} #{creds[:api_key]} \"#{file}\"")
        FileUtils.rm_f(file)
        return true
      end

      SouvlakiRS.logger.error "Airtime import failed - will not delete #{file}"
      false
    end
  end
end
