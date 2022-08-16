# frozen_string_literal: true

require 'fileutils'
require 'filemagic'
require 'uri'

module SouvlakiRS
  # utilities
  module Util
    #
    # joins libretime's install path with a subfolder for copying files to
    def self.get_show_path(name)
      File.join(AIRTIME_CONFIG[:install_root], name)
    end

    #
    # tmp file
    def self.get_tmp_path(name = nil)
      return TMP_DIR_PATH if name.nil?

      File.join(TMP_DIR_PATH, name)
    end

    #
    # ensure dest directory exists TODO: check
    def self.check_destination(path, _opts = {})
      unless Dir.exist?(path)
        begin
          FileUtils.mkdir_p(path)
        rescue Errno::ENOENT
          SouvlakiRS.logger.error "Error making directory #{path}"
          return false
        end
      end

      true
    end

    #
    # check that the path looks like an mp3 file
    def self.get_type_desc(file)
      return FileMagic.new.file(file) if File.exist?(file) && File.size(file) > 10

      nil
    end

    #
    # check for valid URI
    def self.valid_uri?(uri)
      uri =~ /\A#{URI::DEFAULT_PARSER.make_regexp}\z/
    end
  end
end
