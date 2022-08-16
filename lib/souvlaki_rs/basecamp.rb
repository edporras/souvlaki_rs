# frozen_string_literal: true

require 'net/https'
require 'json'

module SouvlakiRS
  module Basecamp
    USER_AGENT = 'SouvlakiRS Notifier'

    class Comment
      attr_writer :msg_head

      def initialize
        creds = Config.get_host_info(:basecamp)
        raise 'Unable to load basecamp credentials' if creds.nil?

        @base_uri = creds[:base_uri]
        @user_id = creds[:id]
        @project_id = creds[:project]
        @msg_id = creds[:msg_id]
        @username = creds[:username]
        @password = creds[:password]
        @ua_email = creds[:ua_email]

        @msg_head = ''
        @text = []
      end

      #
      # add a line of text
      def add_text(txt)
        @text << txt
        self
      end

      #
      # post a comment to the message
      def post
        root_uri = URI.parse(@base_uri)

        # set up the connection
        Net::HTTP.start(root_uri.host, root_uri.port, use_ssl: true) do |http|
          ids = subscriber_ids(request_message(http))
          return post_comment(http, ids)
        end
      end

      #
      # extract the list of subscriber ids
      def subscriber_ids(response_body)
        ids = JSON.parse(response_body)['subscribers'].map { |sub| sub['id'] }
        SouvlakiRS.logger.info "Retrieved message subscriber ids: #{ids}" unless ids.empty?
        ids
      rescue JSON::ParserError
        raise 'Cannot parse JSON result to determine subscriber ids'
      end

      #
      # request the message
      def request_message(http)
        request = Net::HTTP::Get.new(request_message_uri, headers)
        request.basic_auth(@username, @password)
        http.request(request) do |response|
          return response.body if response.code.eql?('200')
        end

        SouvlakiRS.logger.error("Unable to retrieve basecamp message #{@msg_id} - response code #{response.code}")
        []
      end

      #
      # post a new comment to the message
      def post_comment(http, ids)
        request = Net::HTTP::Post.new(post_comment_uri, headers)
        request.basic_auth(@username, @password)
        request.body = payload(make_content, ids).to_json

        http.request(request) do |response|
          return true if response.code.eql?('201')

          SouvlakiRS.logger.info("Unable to post comment - response code #{response.code}")
        end

        false
      end

      #
      # build the payload for the comment we'll post
      def payload(content, subscriber_ids)
        payload = { 'content' => content }
        payload['subscribers'] = subscriber_ids unless subscriber_ids.empty?
        payload
      end

      #
      # format the comment
      def make_content
        c = "<p>#{@msg_head}<ul>"
        @text.each { |t| c << "<li>#{t}</li>" }
        c << '<ul>'
        c
      end

      #
      # UA header
      def headers
        {
          'User-Agent' => "#{USER_AGENT} (#{@ua_email})",
          'Content-Type' => 'application/json'
        }
      end

      #
      # build URIs
      def request_message_uri
        ep = "#{@base_uri}/#{@user_id}/api/v1/projects/#{@project_id}/messages/#{@msg_id}.json"
        URI.parse(ep).request_uri
      end

      def post_comment_uri
        ep = "#{@base_uri}/#{@user_id}/api/v1/projects/#{@project_id}/messages/#{@msg_id}/comments.json"
        URI.parse(ep).request_uri
      end
    end
  end
end
