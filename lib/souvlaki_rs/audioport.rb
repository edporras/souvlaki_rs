# frozen_string_literal: true

require 'fileutils'
require 'mechanize'

module SouvlakiRS
  #
  # scraping AudioPort.org
  class Audioport
    attr_reader :config, :tmp_dir_path

    def initialize(config, tmp_dir_path)
      @config = config
      @tmp_dir_path = tmp_dir_path
    end

    DATE_FORMAT = '%Y-%m-%d' # audioport date format
    # ====================================================================
    # spider audioport to fetch the most recent entry for a given
    # program and return its mp3 if it matches the date
    def fetch_files(show_name, date, show_name_uri)
      tmp_dir = get_tmp_path('audioport')
      show_date = date.strftime(DATE_FORMAT)
      files = []

      SouvlakiRS.logger.info "Audioport fetch for '#{show_name}', date: #{show_date}"

      begin
        agent = init_agent

        rss, date = rss_shows_available(agent, show_name_uri, show_date)
        return [] unless rss

        SouvlakiRS.logger.info "date match (#{date})"

        rslt = from_rss(agent, rss, tmp_dir)
        files << rslt unless rslt.nil?
      rescue StandardError => e
        SouvlakiRS.logger.error "Error when fetching \"#{show_name}\": #{e}"
      end

      # logout
      # logout(agent)
      #      uri = "#{@creds[:base_uri]}?op=logout&amp;"
      #      agent.get(uri)

      files
    end

    private

    #
    # fetch the file using the RSS
    def from_rss(agent, rss, tmp_dir)
      mp3_url = rss.search('//item/enclosure').attribute('url').value

      SouvlakiRS.logger.info "starting download for #{mp3_url}"

      url = URI.parse(mp3_url)
      dest_file = File.join(tmp_dir, File.basename(url.path))
      return dest_file if save_to_disk(download_file(agent, mp3_url), dest_file)

      nil
    end

    # ====================================================================
    # returns the audioport spider agent instance, initializing it and
    # login in when invoked for the first time
    def init_agent
      agent = make_spider

      # initialize and log in
      login(agent)

      unless agent.page.content.include? 'You are logged in.'
        SouvlakiRS.logger.error 'Audioport user login failed'
        raise 'Mechanize failed to create agent' if agent.nil?
      end

      agent
    end

    # creates a configured mechanize instance
    def make_spider
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

    def login(agent)
      # get the login page
      agent.get("#{config[:base_uri]}?op=login&amp;")

      # There are two forms on the page with the same script:
      # - GET form for search
      # - POST form for login in
      # Submit the login form :)
      agent.page.form_with(method: 'POST') do |f|
        f.email    = config[:username]
        f.password = config[:password]
      end.submit
    end

    # def logged_in?(agent)
    #   raise 'XML File' if agent.page.instance_of? == Mechanize::XmlFile

    #   !agent.page.link_with(text: 'Logout').nil?
    # end

    # def logout(agent)
    #   logout_btn = agent.page.link_with(text: 'Logout')
    #   logout_btn&.click
    # end

    #
    # tmp file
    def get_tmp_path(name = nil)
      return tmp_dir_path if name.nil?

      File.join(tmp_dir_path, name)
    end

    def to_date(node)
      Time.parse(node.text).strftime(DATE_FORMAT)
    end

    #
    # checks the RSS to see if a program is available for the given date
    def rss_shows_available(agent, show_name_uri, show_date)
      # go to the show's RSS feed
      rss_uri = "/rss.php?series=#{show_name_uri}"
      rss = agent.get(rss_uri)

      SouvlakiRS.logger.info "fetched RSS feed from '#{rss_uri}', status code: #{agent.page.code.to_i}"

      chan_pub_date = to_date(rss.search('//channel/pubDate'))

      if chan_pub_date > show_date
        SouvlakiRS.logger.info " RSS pub date (#{chan_pub_date}) is more recent than requested date"
        return nil
      end

      SouvlakiRS.logger.info " RSS was last updated on #{chan_pub_date}"

      date = to_date(rss.search('//item/pubDate'))
      if date != show_date
        SouvlakiRS.logger.info "  item date #{date} does not match"
        return nil
      end

      [rss, date]
    end

    def download_file(agent, url)
      data = agent.get(url)
      unless data
        SouvlakiRS.logger.error 'download failed'
        return nil
      end

      data
    end

    def save_to_disk(data, dest_file)
      return false if data.nil?

      FileUtils.rm_f(dest_file) # in case we wrote and aborted previously
      data.save_as(dest_file)

      SouvlakiRS.logger.info "File saved: #{dest_file}"
      true
    end
  end
end
