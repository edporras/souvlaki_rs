# frozen_string_literal: true

require 'fileutils'
require 'mechanize'

module SouvlakiRS
  #
  # scraping AudioPort.org
  class Audioport
    attr_reader :config, :tmp_dir

    def initialize(config, tmp_dir_path)
      @config = config
      @tmp_dir = File.join(tmp_dir_path, 'audioport')
    end

    DATE_FORMAT = '%Y-%m-%d' # audioport date format
    # ====================================================================
    # spider audioport to fetch the most recent entry for a given
    # program and return its mp3 if it matches the date
    def fetch_files(program)
      program = init_fields(program)
      files = []

      SouvlakiRS.logger.info " Trying to fetch: '#{program[:pub_title]}', use html? #{program[:use_html]}"

      begin
        agent = init_agent
        rss, date = rss_shows_available(agent, program[:show_name_uri], program[:show_date])
        return [] unless rss

        SouvlakiRS.logger.info " date match (#{date})"

        files += program[:use_html] ? from_html(agent, program) : from_rss(agent, rss)
      rescue StandardError => e
        SouvlakiRS.logger.error "  Fetch error: #{e}"
      end

      # logout
      # logout(agent)
      #      uri = "#{@creds[:base_uri]}?op=logout&amp;"
      #      agent.get(uri)

      files
    end

    private

    def init_fields(program)
      program[:show_name_uri] = program[:ap_uri] || program[:pub_title].tr(' ', '+')
      program[:show_date] = program[:pub_date].strftime(DATE_FORMAT)
      program[:use_html] |= false
      program[:uri] = "/index.php?op=series&series=#{program[:show_name_uri]}"
      program[:origin] = "#{config[:base_uri]}/#{program[:uri]}"
      program
    end

    #
    # fetch the file using the RSS
    def from_rss(agent, rss)
      mp3_url = rss.search('//item/enclosure').attribute('url').value

      files = []
      data, filename = download_file(agent, mp3_url)
      dest_file = save_to_disk(data, filename)
      files << dest_file if dest_file

      files
    end

    #
    # fetch the files using the HTML page
    def from_html(agent, program)
      page = agent.get(program[:uri])
      SouvlakiRS.logger.info "fetched HTML feed from '#{program[:uri]}', status code: #{agent.page.code.to_i}"

      num_matches = html_page_dates(page).select { |d| d.eql? program[:pub_date].to_s }.size
      titles = html_page_titles(page).take(num_matches)
      SouvlakiRS.logger.info " found #{num_matches} matches"

      files = []
      html_page_download_urls(page, num_matches).each do |download_page|
        page = agent.get(download_page)

        mp3_url = html_page_download_href(page)
        data, filename = download_file(agent, mp3_url)
        dest_file = save_to_disk(data, filename)
        files << dest_file if dest_file
      end

      program[:html_titles] = titles
      files
    end

    #
    # page.xpath('//table[@id="content"]//tr[@class="boxSeparateA" or @class="boxSeparateB"]/td')
    #     .each_slice(5).map{|td_list| td_list[3].text.gsub(/[[:space:]]/, '')}
    def html_page_dates(page)
      page.xpath('//table[@id="content"]//tr[@class="boxSeparateA" or @class="boxSeparateB"]/td')
          .each_slice(5)
          .map { |td_list| td_list[3] }
          .take(4)
          .map { |date_str| to_date(date_str) }
    end

    def html_page_titles(page)
      page.xpath('//table[@id="content"]//tr[@class="boxSeparateA" or @class="boxSeparateB"]/td/a')
          .map(&:text)
          .each_slice(2)
          .take(4)
          .map(&:first)
    end

    #
    # page.xpath('//table[@id="content"]//tr[@class="boxSeparateA" or @class="boxSeparateB"]/td/a/@href')
    #     .map {|link| link.value}.select {|link| !link.include? "producer-info"}
    def html_page_download_urls(page, count)
      page.xpath('//table[@id="content"]//tr[@class="boxSeparateA" or @class="boxSeparateB"]/td/a/@href')
          .map(&:value)
          .reject { |link| link.include? 'producer-info' }
          .take(count)
    end

    def html_page_download_href(page)
      page.xpath("//td[@class='boxContentInfo']//img[@src='/resources/images/icon-download-on.gif']/parent::a")
          .attr('href').value
    end

    # ====================================================================
    # returns the audioport spider agent instance, initializing it and
    # login in when invoked for the first time
    def init_agent
      agent = login(make_spider)
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
        agent.open_timeout = 60
        agent.read_timeout = 60
        agent.pluggable_parser['audio/mpeg'] = Mechanize::Download
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

      agent
    end

    # def logged_in?(agent)
    #   raise 'XML File' if agent.page.instance_of? == Mechanize::XmlFile

    #   !agent.page.link_with(text: 'Logout').nil?
    # end

    # def logout(agent)
    #   logout_btn = agent.page.link_with(text: 'Logout')
    #   logout_btn&.click
    # end

    def to_date(node)
      Time.parse(node).strftime(DATE_FORMAT)
    end

    #
    # checks the RSS to see if a program is available for the given date
    def rss_shows_available(agent, show_name_uri, show_date)
      # go to the show's RSS feed
      rss_uri = "/rss.php?series=#{show_name_uri}"
      rss = agent.get(rss_uri)

      SouvlakiRS.logger.info "fetched RSS feed from '#{rss_uri}', status code: #{agent.page.code.to_i}"

      chan_pub_date = to_date(rss.search('//channel/pubDate').text)
      if chan_pub_date > show_date
        SouvlakiRS.logger.info " RSS pub date (#{chan_pub_date}) is more recent than requested date"
        return nil
      end

      SouvlakiRS.logger.info " RSS was last updated on #{chan_pub_date}"

      date = to_date(rss.search('//item/pubDate').text)
      if date != show_date
        SouvlakiRS.logger.info "  item date #{date} does not match"
        return nil
      end

      [rss, date]
    end

    #
    # fetch the file pointed to by url
    def download_file(agent, url)
      SouvlakiRS.logger.info " starting download for #{url}"

      data = agent.get(url)
      unless data
        SouvlakiRS.logger.error '  download failed'
        return nil
      end

      filename = get_response_filename(data) || filename_from_url(url)
      [data, filename]
    end

    #
    # extract it from content-disposition header
    def get_response_filename(data)
      cnt_dispo = data.header['content-disposition']
      m = /^attachment;(\s*)filename=(.*);/.match(cnt_dispo)
      return m[2] unless m.nil?

      nil
    end

    #
    # fallback to extract from the mp3's url.. might not be ideal
    def filename_from_url(mp3_url)
      File.basename(URI.parse(mp3_url).path)
    end

    #
    # writes the data blob to the given path components
    def save_to_disk(data, filename)
      return nil if data.nil?

      dest_file = File.join(tmp_dir, filename)
      FileUtils.rm_f(dest_file) # in case we wrote and aborted previously
      data.save_as(dest_file)
      SouvlakiRS.logger.info " File saved: #{dest_file}"
      dest_file
    end
  end
end
