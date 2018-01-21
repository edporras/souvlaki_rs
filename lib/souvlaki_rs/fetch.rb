require 'fileutils'
require 'open-uri'
require 'rss'

module SouvlakiRS

  module Fetch
    # ====================================================================
    # fetch a file and save to disk
    def self.fetch_file(uri, dest)

      if !File.exist?(dest)

        SouvlakiRS::logger.info "Fetching \"#{uri}\""

        # file hasn't been fetched
        begin
          File.open(dest, 'wb') do |saved_file|
            open(uri, 'rb') do |read_file|
              saved_file.write(read_file.read)
            end
          end
        rescue OpenURI::HTTPError => error
          response = error.io
          SouvlakiRS::logger.error "Read error when fetching \"#{uri}\": #{response.status[1]}"
        rescue Timeout::Error
          response = error.io
          SouvlakiRS::logger.error "Connection timeout error when fetching \"#{uri}\": #{response.status[1]}"
          if File.exist(dest)
            FileUtils.rm(dest)
            SouvlakiRS::logger.info "deleting remaining file"
          end
        rescue Exception => e
          SouvlakiRS::logger.error "Error when fetching \"#{uri}\": #{e.message}"
          return false
        end

      else
        SouvlakiRS::logger.info "File #{dest} already downloaded"
      end

      # check to see if it looks like an MP3
      if !File.exist?(dest)
        SouvlakiRS::logger.error "File \"#{dest}\" download failed"
        return false
      end

      if File.zero?(dest)
        SouvlakiRS::logger.error "File \"#{dest}\" is empty. Deleting."
        FileUtils.rm_f(dest)
        return false
      end

      desc = SouvlakiRS::Util.get_type_desc(dest)
      if (!desc || (!desc.include?("MP3") && !desc.include?("MPEG")))
        SouvlakiRS::logger.error "File \"#{dest}\" does not look to be an MPEG audio file (#{desc})"
        FileUtils.rm_f(dest)
        return false
      end

      SouvlakiRS::logger.info "File saved. (#{desc})"
      true
    end


    # ====================================================================
    # parse an RSS file to get the top-most RSS entry. If date is nil,
    # the most recent (top-most) entry is returned
    def self.find_rss_entry(uri, date = nil)
      f = RSS::Parser.parse(uri, false)

      if f == nil
        SouvlakiRS::logger.error "Unable to parse rss feed #{uri}"
        return nil
      end

      SouvlakiRS::logger.info "Fetching file from #{f.feed_type} feed at #{uri}"

      # try to parse it w/ standard ruby RSS
      case f.feed_type
      when 'rss'

        f.items.each do |item|

          # return this (first entry) if no date is given
          return item.enclosure.url if date == nil

          # otherwise, compare date to the item's pub date but stop at
          # anything prior to it
          pubdate = item.pubDate.to_date

          SouvlakiRS::logger.info "Searching entry by date: #{date} vs. #{pubdate}"

          break if pubdate < date

          if pubdate.to_s.eql?(date.to_s)
            SouvlakiRS::logger.info "Match found: '#{item.enclosure.url}'"
            return item.enclosure.url
          end
        end

      when 'atom'
        SouvlakiRS::logger.error "Atom feeds not supported yet"
        #        pp f.items.first
        #        f.items.each { |item| puts item.title.content }
      end

      nil
    end

  end

end
