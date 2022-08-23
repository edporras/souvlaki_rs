# frozen_string_literal: true

module SouvlakiRS
  class Airtime
    attr_reader :install_root, :script_path, :api_key

    def initialize(config)
      @install_root = config[:install_root]
      @script_path = File.join(@install_root, 'bin', 'libretime-import')
      @api_key = config[:api_key]
    end

    def import(file, track_type = 'syndicated')
      raise 'import_script_path option is not specified in config' if
        !File.exist?(script_path) || !File.executable?(script_path)

      if system("#{script_path} #{api_key} \"#{file}\" #{track_type}")
        FileUtils.rm_f(file)
        return true
      end

      SouvlakiRS.logger.error "Airtime import failed - will not delete #{file}"
      false
    end
  end
end
