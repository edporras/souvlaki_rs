# -*- coding: utf-8 -*-
require 'fileutils'
require 'mechanize'
require_relative 'config'

module SouvlakiRS
  #
  # scraping AudioPort.org
  module Audioport
    @creds = SouvlakiRS::Config.get_host_info(:audioport)
    @mm = nil
    @TMP_DIR = nil

    # ====================================================================
    # returns the audioport spider agent instance, initializing it and
    # login in when invoked for the first time
    def self.spider
      if @mm.nil?
        @TMP_DIR = SouvlakiRS::Util.get_tmp_path('audioport')

        # initialize and log in
        @mm = Mechanize.new do |agent|
          agent.user_agent_alias = 'Windows Mozilla'
          agent.follow_meta_refresh = true
          agent.redirect_ok = true
          agent.keep_alive = true
          agent.open_timeout = 30
          agent.read_timeout = 30
          #          agent.pluggable_parser['audio/mpeg'] = Mechanize::DirectorySaver.save_to(SouvlakiRS::Util.get_tmp_path)
        end

        # get the login page
        uri = "#{@creds[:base_uri]}?op=login&amp;"
        @mm.get(uri)

        # There are two forms on the page with the same script:
        # - GET form for search
        # - POST form for login in
        # Submit the login form :)
        @mm.page.form_with(method: 'POST') do |f|
          f.email    = @creds[:username]
          f.password = @creds[:password]
        end.submit

        if !@mm.page.content.include? 'You are logged in.'
          SouvlakiRS.logger.error 'Audioport user login failed'
          raise 'Couldn\'t log in'
        end

        SouvlakiRS.logger.info 'Audioport user logged in'
      end

      @mm
    end

    # ====================================================================
    # spider audioport to fetch the most recent entry for a given
    # program and return its mp3 if it matches the date
    def self.fetch_files(show_name, date, show_name_uri)
      files = []

      # audioport date format
      show_date = date.strftime('%Y-%m-%d')

      SouvlakiRS.logger.info "Audioport fetch for '#{show_name}', date: #{show_date}"

      # go to the show's page
      uri = "#{@creds[:base_uri]}?op=series&amp;series=#{show_name_uri}"

      begin
        spider.get(uri)
        SouvlakiRS.logger.info "fetched '#{uri}', status code: #{spider.page.code.to_i}"

        # we have the page of results. Audioport formats this a little funky:
        # <div id="result_set">
        #   <table>
        #     <tr> td headings </tr>
        #     <tr><td>latest show's 'program name' </tr> (unterminated td)
        #     <tr><td></td><td>producer</td><td>date (YYYY-MM-DD format)</td><td>length</td></tr>
        #
        # start by getting the list of tr
        trs = spider.page.search('//div[@id="result_set"]').search('tr')

        ii = 2
        while ii < trs.length
          # therefore, we find each entry every-other one starting from
          # the 3rd TR and then fetch the 3rd td to extract the date -
          # also, replace \u00a0 for &nbsp; and strip to remove
          # surrounding whitespace
          date = trs[ii].search('td')[2].text.delete(' ').strip

          break if date < show_date

          SouvlakiRS.logger.info " TR #{ii} is #{date}"

          if date == show_date
            # we have a match so we must follow to the next page which
            # actually carries the link to the MP3. Grab the first link to
            # the programs that corresponds to the entry we matched
            links = spider.page.links
            uris = links.select { |l| l.href.include? 'program-info' if l.href }
            uri = uris[(ii / 2) - 1]

            SouvlakiRS.logger.info "date match (#{date}) - following #{uri.href}"
            uri.click

            # we're now on the final page that contains the link(s) to
            # download - look by searching for 'file_id'.
            uri_list = spider.page.links.select { |l| l.href.include? 'file_id' if l.href }

            SouvlakiRS.logger.warn 'No entries found for date' if uri_list.empty?

            jj = 0
            uri_list.each do |l|
              SouvlakiRS.logger.info "starting download for #{l.href}"

              # fetch the data
              data = spider.get(l.href)
              if data
                # filename might be in header's content-disposition
                filename = ''
                if data.header['content-disposition']
                  cd = data.header['content-disposition'].split('=')
                  if cd.length > 1
                    # extract the filename
                    path = cd[1].gsub(/\A"|"\Z/, '')
                    filename = "#{path.slice(0..(path.downcase.index('.mp3')))}mp3"
                  end
                end

                SouvlakiRS.logger.info "Header content-disposition: #{filename}"

                if filename.empty?
                  # not included - make one up
                  filename = "#{show_date}-#{show_name}-#{jj}.mp3"
                end

                dest_file = File.join(@TMP_DIR, filename)

                # delete if it exists
                FileUtils.rm_f(dest_file) if File.exist?(dest_file)

                data.save_as(dest_file)

                SouvlakiRS.logger.info "File saved: #{dest_file}"

                # either downloaded it or file was there already
                files << dest_file

                # some audioport pages have the file linked twice w/
                # different urls. TODO: don't bother fetching more than
                # 1 until we find out if there are cases we should -
                # perhaps check label?
                break
              else
                SouvlakiRS.logger.error 'download failed'
              end

              jj += 1
            end
          end

          ii += 2
        end
      rescue StandardError => e
        SouvlakiRS.logger.error "Error when fetching \"#{uri}\": #{e}"
        return nil
      end

      # logout
      logout_btn = spider.page.link_with(text: "Logout")
      logout_btn.click unless logout_btn.nil?
#      uri = "#{@creds[:base_uri]}?op=logout&amp;"
#      spider.get(uri)

      files
    end
  end
end
