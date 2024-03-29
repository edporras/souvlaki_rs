# frozen_string_literal: true

require_relative 'helper'

module SouvlakiRS
  class TestTag < Test::Unit::TestCase
    context 'rewritable_title?' do
      setup do
        @def_album = 'album title'
      end

      should 'true when title is nil' do
        assert_true Tag.rewritable_title?(nil, @def_album)
      end

      should 'true when title is empty' do
        assert_true Tag.rewritable_title?('', @def_album)
      end

      should 'true when title and def_album are equal is within block' do
        assert_true Tag.rewritable_title?(nil, @def_album)
      end

      should 'true when title looks like a filename' do
        assert_true Tag.rewritable_title?('some-file.mp3', @def_album)
      end

      should 'false otherwise' do
        assert_false Tag.rewritable_title?('Some title', @def_album)
      end
    end

    context 'cleanup_title' do
      should '' do
        assert_equal 'Prog Title Episode Name', Tag.cleanup_title({ title: 'Prog Title: Prog Title Episode Name' }, 'Prog Title')
      end
    end
  end
end
