# frozen_string_literal: true

require 'taglib'

module SouvlakiRS
  module Tag
    #
    # retag a file fetched from web
    def self.retag_file(file, def_album, def_artist, pub_date, write_tags, rewrite_title = true)
      tags = audio_file_read_tags(file)

      # prep the title - prepend the date to the album (show name) when
      # 1. there's no title tag
      # 2. the title tag equals the album title (show name)
      # 3. the title tag looks like a file name w/ .mp3 extension
      # 4. config forces it
      if tags[:title].nil? ||
         tags[:title] == def_album ||
         (tags[:title].length.positive? && tags[:title].downcase.include?('mp3')) ||
         rewrite_title
        date = pub_date.strftime('%Y%m%d')
        old_t = tags[:title] || ''
        tags[:title] = "#{date} #{def_album}"

        SouvlakiRS.logger.warn "Title ('#{old_t}') will be overwritten to '#{tags[:title]}'"
      elsif tags[:title] && tags[:title].downcase.start_with?(def_album.downcase)
        # title starts with program name - remove it to be less wordy and clean up leading -, :, or ws
        tags[:title] = tags[:title][def_album.length..].gsub(/^[\sfor\-:]*/, '')
        SouvlakiRS.logger.info "Trimmed title: '#{tags[:title]}'"
      end

      # override artist & album (program name) to our consistent one
      tags[:artist] = def_artist
      tags[:album] = def_album

      # and set year because, why not
      tags[:year] = pub_date.strftime('%Y').to_i

      audio_file_write_tags(file, tags) if write_tags

      tags
    end

    #
    # tries to retag a user's file imported manually
    def self.retag_user_file(file, tags, def_album, def_artist = nil)
      # if there's no title set, do nothing. Return nil to indicate error
      if tags[:title].nil?
        SouvlakiRS.logger.error "No title tag set for #{file}"
        return nil
      end

      # if the title looks like a filename, remove the extension
      if tags[:title].downcase.end_with?('.mp3')
        SouvlakiRS.logger.warn "Title tag looks like a filename (#{file}) - removing extension from tag"
        tags[:title] = tags[:title][0..-4]
      end

      # replace artist if specified
      tags[:artist] = def_artist if def_artist

      # force album (program name or type)
      tags[:album] = def_album

      audio_file_write_tags(file, tags)

      tags
    end

    #
    # read tags from a file
    def self.audio_file_read_tags(filepath)
      tags = { title: nil, artist: nil, album: nil, year: nil }

      TagLib::MPEG::File.open(filepath) do |file|
        # Read basic attributes
        id3v2 = file.id3v2_tag
        if id3v2
          SouvlakiRS.logger.info "ID3V2 title '#{id3v2.title}'"
          tags[:title]  = copy_tag(id3v2.title)
          tags[:artist] = copy_tag(id3v2.artist)
          tags[:album]  = copy_tag(id3v2.album)
          tags[:year]   = id3v2.year if id3v2.year != 0
        end

        if tags[:title].nil? || tags[:artist].nil?
          id3v1 = file.id3v1_tag

          if id3v1
            SouvlakiRS.logger.info "ID3V1 title '#{id3v1.title}'"
            tags[:title]  = copy_tag(id3v1.title) if tags[:title].nil?
            tags[:artist] = copy_tag(id3v1.artist) if tags[:artist].nil?
          end
        end

        tags[:length] = file.audio_properties.length if file.audio_properties
        return tags
      end

      tags
    end

    # --------------------------------------------------------
    def self.copy_tag(tag)
      if tag
        new_t = tag.strip
        return new_t if new_t.length.positive?
      end
      nil
    end

    #
    # tag a file
    def self.audio_file_write_tags(filepath, tags)
      TagLib::MPEG::File.open(filepath) do |file|
        [file.id3v1_tag, file.id3v2_tag].each do |tag|
          # Write basic attributes
          tag.album  = tags[:album]
          tag.artist = tags[:artist] unless tags[:artist].nil?
          tag.title  = tags[:title] unless tags[:title].nil?
          tag.year   = tags[:year] unless tags[:year].nil?
        end

        file.save
        return true
      end

      false
    end
  end
end
