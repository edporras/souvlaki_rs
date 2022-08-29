# frozen_string_literal: true

require_relative 'helper'

module SouvlakiRS
  class TestProgram < Test::Unit::TestCase
    context 'prepare program config' do
      setup do
        @thedate = Date.new(2022, 12, 1)
        @options = { req_date: @thedate }
      end

      should 'backdate to yesterday when needed' do
        prog = Program.prepare({ source: :rss }, @options)
        assert_equal @thedate - 1, prog[:pub_date]
      end

      should 'not backdate to yesterday when indicated' do
        prog = Program.prepare({ source: :rss, today: true }, @options)
        assert_equal @thedate, prog[:pub_date]
      end

      should 'add :file_url to :file programs' do
        prog = Program.prepare({ base_url: 'http://www', source: :file }, @options)
        assert_equal 'http://www', prog[:file_url]
      end

      should 'add formatted :file_url to :file programs when `:format` is present' do
        prog = Program.prepare({ base_url: 'http://www', pub_date: @thedate, format: '%Y%m%d', source: :file }, @options)
        assert_equal 'http://www/20221130', prog[:file_url]
      end

      should 'set :retitle to true if not present' do
        prog = Program.prepare({ base_url: 'http://www', source: :file }, @options)
        assert_equal true, prog[:retitle]
      end

      should 'accept :retitle if present' do
        prog = Program.prepare({ base_url: 'http://www', source: :file, retitle: false }, @options)
        assert_equal false, prog[:retitle]
        prog = Program.prepare({ base_url: 'http://www', source: :file, retitle: true }, @options)
        assert_equal true, prog[:retitle]
      end
    end

    context 'determine file_duration' do
      should 'return nil when duration is within block' do
        assert_nil Program.file_duration({ block: 30, tags: { length: 1750 } })
      end

      should 'return string to report duration when block is exceeded' do
        assert_equal '00:30:11', Program.file_duration({ block: 30, tags: { length: 1811 } })
      end

      should 'return nil when :block field is not given' do
        assert_nil Program.file_duration({ tags: { length: 2300 } })
      end
    end

    context 'program validation' do
      should 'allow valid program configs' do
        progs = [{ pub_title: 'Title 1', creator: 'Creator 1', name: 'Name 1', source: :rss, feed: 'http://1' },
                 { pub_title: 'Title 2', creator: 'Creator 2', name: 'Name 2', source: :file, base_url: 'http://1' },
                 { pub_title: 'Title 3', creator: 'Creator 3', name: 'Name 3', source: :audioport }]
        progs.each { |p| assert_true Program.valid?(p) }
      end

      should 'fail on invalid fields' do
        assert_false Program.valid?({ pub_title: nil, creator: 'C', name: 'N', source: :rss })
        assert_false Program.valid?({ pub_title: 'T', creator: nil, name: 'N', source: :rss })
        assert_false Program.valid?({ pub_title: 'T', creator: 'C', name: nil, source: :rss })
      end

      should 'fail on unknown :source' do
        assert_false Program.valid?({ pub_title: 'Title 1', creator: 'Creator 1', name: 'Name 1', source: :xyz })
      end

      should 'fail on rss config missing :feed' do
        assert_false Program.valid?({ pub_title: 'Title 1', creator: 'Creator 1', name: 'Name 1', source: :rss })
      end

      should 'fail on file config missing :base_url' do
        assert_false Program.valid?({ pub_title: 'Title 2', creator: 'Creator 2', name: 'Name 2', source: :file })
      end

      should 'allow valid genre' do
        assert_true Program.valid?({ pub_title: 'T', creator: 'C', name: 'N', source: :rss, feed: 'http://1', genre: :rock })
      end

      should 'fail on invalid genre' do
        assert_false Program.valid?({ pub_title: 'T', creator: 'C', name: 'N', source: :rss, feed: 'http://1', genre: :xyz })
      end
    end
  end
end
