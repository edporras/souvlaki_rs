# frozen_string_literal: true

require 'net/https'
require 'json'

module SouvlakiRS
  module Basecamp
    USER_AGENT = 'SouvlakiRS Fetcher Notifier'

    class Comment
      def initialize(msg_head)
        @msg_head = msg_head
        @text = []
      end

      #
      # add a line of text
      def add_text(txt)
        @text << txt
        self
      end

      #
      # post the message
      def post
        creds = SouvlakiRS::Config.get_host_info(:basecamp)

        if creds.nil?
          SouvlakiRS.logger.error('Unable to load basecamp credentials')
          return false
        end

        # prepare fields for the message
        msg_id = creds[:msg_id]
        uri = URI.parse(creds[:base_uri])

        # set up the connection
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          headers = {
            'User-Agent' => "#{USER_AGENT} (#{creds[:ua_email]})",
            'Content-Type' => 'application/json'
          }

          # get the message first - wasteful but we need to get the
          # list of subscribers
          uri = URI.parse("#{creds[:base_uri]}/#{creds[:id]}/api/v1/projects/#{creds[:project]}/messages/#{msg_id}.json")
          request = Net::HTTP::Get.new(uri.request_uri, headers)
          request.basic_auth(creds[:username], creds[:password])
          response = http.request(request)
          SouvlakiRS.logger.info "GET '#{uri.request_uri}' - response code #{response.code}"

          unless response.code.eql?('200')
            SouvlakiRS.logger.error "Unable to retrieve basecamp message #{msg_id}"
            return false
          end

          # get the list of subscribe ids
          ids = []
          begin
            ids = JSON.parse(response.body)['subscribers'].map { |sub| sub['id'] }
            SouvlakiRS.logger.info "Retrieved message subscriber ids: #{ids}"
          rescue JSON::ParserError
            SouvlakiRS.logger.error 'Cannot parse JSON result'
            return false
          end

          # now post the message
          uri = URI.parse("#{creds[:base_uri]}/#{creds[:id]}/api/v1/projects/#{creds[:project]}/messages/#{msg_id}/comments.json")
          request = Net::HTTP::Post.new(uri.request_uri, headers)
          request.basic_auth(creds[:username], creds[:password])

          payload = {
            'content' => message
          }
          payload['subscribers'] = ids unless ids.empty?
          request.body = payload.to_json

          # send the request
          response = http.request(request)
          SouvlakiRS.logger.info "POST '#{uri.request_uri}' - response code #{response.code}"

          return true if response.code.eql?('201')
        end

        false
      end

      #
      # format the message
      def message
        c = "<p>#{@msg_head}<ul>"
        @text.each { |t| c << "<li>#{t}</li>" }
        c << '<ul>'
        c
      end
    end
  end
end
