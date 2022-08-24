# frozen_string_literal: true

require_relative 'helper'

module SouvlakiRS
  class TestBasecamp2 < Test::Unit::TestCase
    context 'Basecamp comment notifications' do
      setup do
        @bc2 = Basecamp2.new(base_uri: 'http://',
                             user_id: 'me',
                             project: '123',
                             username: 'xx',
                             password: 'yy',
                             ua_email: 'me@some.org',
                             msg_id: 'zz')
      end

      should 'valid headers' do
        hdrs = @bc2.headers
        assert_not_nil hdrs

        assert_equal 'SouvlakiRS Notifier (me@some.org)', hdrs['User-Agent']
        assert_equal 'application/json', hdrs['Content-Type']
      end

      should 'valid request_message_uri' do
        assert_equal '//api/v1/projects/123/messages/1.json', @bc2.request_message_uri('1')
      end

      should 'valid post_comment_uri' do
        assert_equal '//api/v1/projects/123/messages/1/comments.json', @bc2.post_comment_uri('1')
      end

      teardown do
        @bc2 = nil
      end
    end
  end
end
