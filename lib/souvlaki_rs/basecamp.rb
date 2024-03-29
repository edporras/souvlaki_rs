# frozen_string_literal: true

require 'net/https'
require 'json'

module SouvlakiRS
  class Basecamp2
    USER_AGENT = 'SouvlakiRS Notifier'
    attr_reader :base_uri, :user_id, :project_id, :username, :password, :root_uri, :global_msg_id
    attr_accessor :msg_list

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
    def register_ok(program)
      src = program[:origin] ? " (<a href=\"#{program[:origin]}\">source</a>)" : ''
      msg = "#{program[:tags][:title]}#{src}"

      # report warning if duration info is given and program's looks odd
      if program[:d_hms]
        msg << " (Length warning: #{program[:d_hms]})"
        SouvlakiRS.logger.warn "File duration (#{program[:d_hms]}) - block is #{program[:block_len]}"
      end

      add_success_text(program[:msg_id], msg)
    end

    def register_error(program)
      return unless program.key?(:err_msg)

      msg = program[:name]
      msg = "<a href=\"#{program[:origin]}\">#{msg}</a>" if program[:origin]
      add_error_text(program[:msg_id], program[:err_msg], msg)
    end

    #
    # post a comment to the message
    def post_comment
      msg_list.each do |msg_id, msg_data|
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
      c = "<p>SRS v#{SouvlakiRS::VERSION} auto-import:</p>#{items_to_html_list(msg_data[:text])}"

      unless msg_data[:error].empty?
        html_errors = errors_to_html_list(errors_by_msg(msg_data[:error]))
        c << "<br /><p>Unable to fetch:</p>#{html_errors}"
      end

      c
    end

    def errors_by_msg(err)
      errors = []
      errors << err.group_by { |e| e[:text] }
                   .sort_by { |k, _v| k }
                   .map do |k, v|
                     s = v.map { |e| e[:error_msg] }.join(', ')
                     "#{k}: #{s}"
                   end
      errors.flatten
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

    def add_success_text(msg_id, text)
      msg_id ||= global_msg_id
      msg_list[msg_id] = new_msg unless msg_list.key?(msg_id)
      msg_list[msg_id][:text] << text
    end

    def add_error_text(msg_id, text, error_msg)
      msg_id ||= global_msg_id
      msg_list[msg_id] = new_msg unless msg_list.key?(msg_id)
      msg_list[msg_id][:error] << { error_msg:, text: }
    end

    def new_msg
      { text: [], error: [] }
    end

    def items_to_html_list(items)
      s = '<ul>'
      items.each { |t| s += "<li>#{t}</li>" }
      s += '</ul>'
      s
    end

    def errors_to_html_list(errors)
      s = '<ul>'
      errors.each { |t| s += "<li>#{t}</li>" }
      s += '</ul>'
      s
    end
  end
end
