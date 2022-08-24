# frozen_string_literal: true

require 'souvlaki_rs'

require File.join(File.dirname(__FILE__), 'helper')

module SouvlakiRS
  class TestConfig < Test::Unit::TestCase
    context 'Config File Reader' do
      setup do
        @config = SouvlakiRS::Config.new('test/fixtures/test-config.edn')
      end

      should 'get_host_info' do
        audioport = @config.get_host_info(:audioport)
        assert_not_nil audioport

        assert_equal %i[base_uri username password], audioport.keys
      end

      should 'get_host_info returns throws on not-found' do
        assert_raises(RuntimeError) { @config.get_host_info(:xyz) }
      end

      should 'get_program_code' do
        prog1 = @config.get_program_info(:tp1)
        assert_not_nil prog1

        assert_equal %i[pub_title creator name source feed block genre code], prog1.keys
      end

      should 'get_program_code returns nil on not-found' do
        prog1 = @config.get_program_info(:xyz)
        assert_nil prog1
      end

      teardown do
        @config = nil
      end
    end
  end
end
