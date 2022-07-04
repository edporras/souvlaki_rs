# frozen_string_literal: true

require 'fileutils'
require 'mechanize'
require_relative 'config'

module SouvlakiRS
  #
  # scraping AudioPort.org
  module Audioport
    # ====================================================================
    # returns the audioport spider agent instance, initializing it and
    # login in when invoked for the first time
    def self.setup_spider(creds)
      # initialize and log in
      agent = create_spider
      login(agent, creds)

      unless agent.page.content.include? 'You are logged in.'
        SouvlakiRS.logger.error 'Audioport user login failed'
        return nil
      end

      SouvlakiRS.logger.info 'Audioport user logged in'
      agent
    end

    def self.logged_in?(agent)
      raise 'XML File' if agent.page.instance_of? == Mechanize::XmlFile

      !agent.page.link_with(text: 'Logout').nil?
    end

    # creates a configured mechanize instance
    def self.create_spider
      Mechanize.new do |agent|
        agent.user_agent_alias = 'Mac Safari'
        agent.follow_meta_refresh = true
        # agent.redirect_ok = true
        agent.keep_alive = true
        agent.open_timeout = 30
        agent.read_timeout = 30
        # agent.pluggable_parser['audio/mpeg'] = Mechanize::DirectorySaver.save_to(SouvlakiRS::Util.get_tmp_path)
      end
    end

    def self.login(agent, creds)
      # get the login page
      agent.get("#{creds[:base_uri]}?op=login&amp;")

      # There are two forms on the page with the same script:
      # - GET form for search
      # - POST form for login in
      # Submit the login form :)
      agent.page.form_with(method: 'POST') do |f|
        f.email    = creds[:username]
        f.password = creds[:password]
      end.submit
    end

    DATE_FORMAT = '%Y-%m-%d'
    # ====================================================================
    # spider audioport to fetch the most recent entry for a given
    # program and return its mp3 if it matches the date
    def self.fetch_files(show_name, date, show_name_uri)
      creds = SouvlakiRS::Config.get_host_info(:audioport)
      agent = setup_spider(creds)
      return [] if agent.nil?

      tmp_dir = SouvlakiRS::Util.get_tmp_path('audioport').freeze
      show_date = date.strftime(DATE_FORMAT) # audioport date format
      files = []

      SouvlakiRS.logger.info "Audioport fetch for '#{show_name}', date: #{show_date}"

      begin
        # go to the show's RSS feed
        rss_uri = "/rss.php?series=#{show_name_uri}"
        rss = agent.get(rss_uri)

        SouvlakiRS.logger.info "fetched RSS feed from '#{rss_uri}', status code: #{agent.page.code.to_i}"

        chan_pub_date = rss.search('//channel/pubDate').text
        chan_pub_date = Time.parse(chan_pub_date).strftime(DATE_FORMAT)

        if chan_pub_date > show_date
          SouvlakiRS.logger.info " RSS pub date (#{chan_pub_date}) is more recent than requested date"
          return files
        else
          SouvlakiRS.logger.info " RSS was last updated on #{chan_pub_date}"

          last_item_date = rss.search('//item/pubDate').text
          date = Time.parse(last_item_date).strftime(DATE_FORMAT)
          if date != show_date
            SouvlakiRS.logger.info "  item date #{date} does not match"
            return files
          end

          SouvlakiRS.logger.info "date match (#{date})"

          mp3_url = rss.search('//item/enclosure').attribute('url').value
          url = URI.parse(mp3_url)
          filename = File.basename(url.path)

          SouvlakiRS.logger.info "starting download for #{mp3_url}"

          # fetch the data
          data = agent.get(mp3_url)
          if data
            dest_file = File.join(tmp_dir, filename)

            # delete if it exists
            FileUtils.rm_f(dest_file) if File.exist?(dest_file)

            data.save_as(dest_file)

            SouvlakiRS.logger.info "File saved: #{dest_file}"

            # either downloaded it or file was there already
            files << dest_file
          else
            SouvlakiRS.logger.error 'download failed'
          end
        end
      rescue StandardError => e
        SouvlakiRS.logger.error "Error when fetching \"#{show_name}\": #{e}"
      end

      # logout
      # logout(agent)
      #      uri = "#{@creds[:base_uri]}?op=logout&amp;"
      #      agent.get(uri)

      files
    end

    def self.logout(agent)
      logout_btn = agent.page.link_with(text: 'Logout')
      logout_btn&.click
    end
  end
end
