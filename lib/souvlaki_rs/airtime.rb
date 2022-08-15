# frozen_string_literal: true

module SouvlakiRS
  module Airtime
    def self.import(file, track_type = 'syndicated')
      script_path = File.join(AIRTIME_CONFIG[:install_root], 'bin', 'libretime-import')

      raise 'import_script_path option is not specified in config' if
        !File.exist?(script_path) || !File.executable?(script_path)

      if system("#{script_path} #{AIRTIME_CONFIG[:api_key]} \"#{file}\" #{track_type}")
        FileUtils.rm_f(file)
        return true
      end

      SouvlakiRS.logger.error "Airtime import failed - will not delete #{file}"
      false
    end
  end
end
