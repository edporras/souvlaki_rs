# frozen_string_literal: true

require 'net/https'
require 'json'

module SouvlakiRS
  class Basecamp2
    USER_AGENT = 'SouvlakiRS Notifier'
    attr_reader :base_uri, :user_id, :project_id, :username, :password, :root_uri

    def initialize(creds)
      @base_uri = creds[:base_uri]
      @user_id = creds[:id]
      @project_id = creds[:project]
      @username = creds[:username]
      @password = creds[:password]
      @ua_email = creds[:ua_email]
      @global_msg_id = creds[:msg_id]
      @msg_list = {}

      @root_uri = URI.parse(base_uri)
    end

    #
    # add a line of text
    def add_text(txt, msg_id = nil)
      msg_id ||= @global_msg_id
      @msg_list[msg_id] = { text: [] } unless @msg_list.key?(msg_id)
      @msg_list[msg_id][:text] << txt
      self
    end

    #
    # post a comment to the message
    def post_comment
      @msg_list.each do |msg_id, msg_data|
        Net::HTTP.start(root_uri.host, root_uri.port, use_ssl: true) do |http|
          message_resp = request_message(http, msg_id)
          if message_resp
            subscriber_ids = subscriber_ids(message_resp)

            SouvlakiRS.logger.info "Retrieved message #{msg_id} subscriber ids: #{subscriber_ids}" unless
              subscriber_ids.empty?

            msg_data[:id] = msg_id
            post(http, msg_data, subscriber_ids)
          end
        end
      end
    end

    #
    # request the message
    def request_message(http, msg_id)
      request = Net::HTTP::Get.new(request_message_uri(msg_id), headers)
      request.basic_auth(username, password)
      http.request(request) do |response|
        return response.body if response.code.eql?('200')

        SouvlakiRS.logger.error("Unable to retrieve basecamp message #{msg_id} - response code #{response.code}")
      end
      nil
    end

    #
    # post a new comment to the message
    def post(http, msg_data, subscriber_ids)
      request = Net::HTTP::Post.new(post_comment_uri(msg_data[:id]), headers)
      request.basic_auth(username, password)
      request.body = payload(msg_data, subscriber_ids).to_json

      http.request(request) do |response|
        return true if response.code.eql?('201')

        SouvlakiRS.logger.info("Unable to post comment - response code #{response.code}")
      end

      false
    end

    #
    # extract the list of subscriber ids
    def subscriber_ids(response_body)
      JSON.parse(response_body)['subscribers'].map { |sub| sub['id'] }
    rescue JSON::ParserError
      raise 'Cannot parse JSON result to determine subscriber ids'
    end

    #
    # build the payload for the comment we'll post
    def payload(msg_data, subscriber_ids)
      payload = { 'content' => make_content(msg_data) }
      payload['subscribers'] = subscriber_ids unless subscriber_ids.empty?
      payload
    end

    #
    # format the comment
    def make_content(msg_data)
      c = "<p>SRS v#{SouvlakiRS::VERSION} auto-import:<ul>"
      msg_data[:text].each { |t| c << "<li>#{t}</li>" }
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
    def request_message_uri(msg_id)
      ep = "#{base_uri}/#{user_id}/api/v1/projects/#{project_id}/messages/#{msg_id}.json"
      URI.parse(ep).request_uri
    end

    def post_comment_uri(msg_id)
      ep = "#{base_uri}/#{user_id}/api/v1/projects/#{project_id}/messages/#{msg_id}/comments.json"
      URI.parse(ep).request_uri
    end
  end
end
