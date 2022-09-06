# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require 'rss'

module SouvlakiRS
  # file fetching
  module Fetch
    # ====================================================================
    # fetch a file and save to disk
    def self.fetch_file(uri, dest)
      if File.exist?(dest)
        SouvlakiRS.logger.info " File #{dest} already downloaded"
      else
        SouvlakiRS.logger.info " Trying to fetch \"#{uri}\""
        # file hasn't been fetched
        begin
          attempts ||= 1
          case io = OpenURI.open_uri(uri)
          when StringIO then File.write(dest, io.read)
          when Tempfile
            begin
              io.close
              FileUtils.mv(io.path, dest)
            end
          end
          SouvlakiRS.logger.info " Wrote to #{dest}"
        rescue OpenURI::HTTPError => e
          SouvlakiRS.logger.error "  Read error: (#{e.io.status[1]})"
          program[:err_msg] = 'File not found'
          return false
        rescue Timeout::Error => e
          SouvlakiRS.logger.error "  Connection timeout error: #{e.io.status[1]}"
          FileUtils.rm(dest)

          if (attempts += 1) < 5
            sleep(60)
            SouvlakiRS.logger.error "   retry # #{attempts - 1}"
            retry
          end
        rescue StandardError => e
          SouvlakiRS.logger.error "  Error: #{e.message}"
          return false
        end
      end

      valid = valid?(dest)
      FileUtils.rm_f(dest) unless valid
      valid
    end

    def self.valid?(dest)
      # check to see if it looks like an MP3
      unless File.exist?(dest)
        SouvlakiRS.logger.error "  File \"#{dest}\" download failed"
        return false
      end

      if File.zero?(dest)
        SouvlakiRS.logger.error "  File \"#{dest}\" is empty. Deleting."
        FileUtils.rm_f(dest)
        return false
      end

      desc = SouvlakiRS::Util.get_type_desc(dest)
      if desc && %w[MP3 MPEG ID3].any? { |w| desc.include?(w) }
        SouvlakiRS.logger.info " File saved. (#{desc})"
        return true
      end

      SouvlakiRS.logger.error "  File \"#{dest}\" does not look to be an MPEG audio file (#{desc})"
      false
    end

    # ====================================================================
    # parse an RSS file to get the top-most RSS entry. If date is nil,
    # the most recent (top-most) entry is returned
    def self.find_rss_entry(uri, date = nil)
      f = RSS::Parser.parse(uri, false)

      if f.nil?
        SouvlakiRS.logger.error " Unable to parse rss feed #{uri}"
        return nil
      end

      SouvlakiRS.logger.info " Trying to fetch file from '#{f.feed_type}' feed at #{uri}"

      # try to parse it w/ standard ruby RSS
      case f.feed_type
      when 'rss'
        f.items.each do |item|
          # return this (first entry) if no date is given
          return item.enclosure.url if date.nil?

          # otherwise, compare date to the item's pub date but stop at
          # anything prior to it
          pubdate = item.pubDate.to_date

          SouvlakiRS.logger.info " Searching entry by date: #{date} vs. #{pubdate}"

          break if pubdate < date

          if pubdate.to_s.eql?(date.to_s)
            SouvlakiRS.logger.info " Match found: '#{item.enclosure.url}'"
            return item.enclosure.url
          end
        end

      when 'atom'
        SouvlakiRS.logger.error 'Atom feeds not supported yet'
        #        pp f.items.first
        #        f.items.each { |item| puts item.title.content }
      end

      nil
    end
  end
end
