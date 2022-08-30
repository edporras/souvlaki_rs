# frozen_string_literal: true

require 'fileutils'
require 'filemagic'

module SouvlakiRS
  module Util
    #
    # ensure dest directory exists
    def self.ensure(path)
      unless Dir.exist?(path)
        begin
          FileUtils.mkdir_p(path)
        rescue Errno::ENOENT
          raise "Error making directory #{path}"
        end
      end

      path
    end

    #
    # check that the path looks like an mp3 file
    def self.get_type_desc(file)
      return FileMagic.new.file(file) if File.exist?(file) && File.size(file) > 10

      nil
    end
  end
end
