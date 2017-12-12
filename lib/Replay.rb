require 'lzma'
require File.dirname(__FILE__) + '/Deck.rb'
require File.dirname(__FILE__) + '/Log.rb'

module Ygoruby
  class ReplayHeader

    REPLAY_COMPRESSED_FLAG = 1
    REPLAY_TAG_FLAG = 2
    REPLAY_DECIDED_FLAG = 4

    attr_accessor :id
    attr_accessor :version
    attr_accessor :flag
    attr_accessor :seed
    attr_accessor :data_size_raw
    attr_accessor :hash
    attr_accessor :props

    define_method(:data_size) {@data_size_raw[0] + @data_size_raw[1] * 0x100 + @data_size_raw[2] * 0x10000 + @data_size_raw[3] * 0x1000000}
    define_method(:is_tag?) {@flag & REPLAY_TAG_FLAG > 0}
    define_method(:is_compressed?) {@flag & REPLAY_COMPRESSED_FLAG > 0}

    def get_lzma_header
      # props -> 0
      # dict_length -> 1-4
      # uncompressed_legth -> 5-12
      byte_array = @props[0, 5] + @data_size_raw + [0, 0, 0, 0]
      byte_array.pack("C*").force_encoding("utf-16le")
    end
  end

  class ReplayReader
    attr_accessor :data
    attr_accessor :pointer

    def initialize(data_string)
      @data = data_string.unpack 'C*'
      @pointer = 0
    end

    def read_data(length)
      data = @data[self.pointer, length]
      @pointer += length
      data
    end

    def read_int8
      data = @data[self.pointer]
      @pointer += 1
      data
    end

    def read_int16
      num = read_int8
      num += read_int8 * 0x100
    end

    def read_int32
      num = read_int8
      num += read_int8 * 0x100
      num += read_int8 * 0x10000
      num += read_int8 * 0x1000000
    end

    def read_byte
      read_int8
    end

    def read_byte_array(length)
      (1..length).map {read_byte}
    end

    def read_next_response
      length = read_int8
      read_data length
    end

    def read_next_pack
      length = read_int32
      (1..length).map {read_int32}
    end

    def read_string(length)
      bytes = read_data length
      s = bytes.pack 'C*'
      s = s.split("\x00\x00").first
      s += "\x00" if s.length % 2 != 0
      s.force_encoding("UTF-16LE").encode("UTF-8")
    end

    def read_all
      @data[@pointer..-1].pack('C*').force_encoding('utf-16le')
    end

    def rewind
      @pointer = 0
    end
  end

  class Replay
    attr_accessor :header
    attr_accessor :host_name, :client_name
    attr_accessor :start_lp, :start_hand
    attr_accessor :draw_count, :opt
    attr_accessor :host_deck, :client_deck

    attr_accessor :tag_host_name, :tag_client_name
    attr_accessor :tag_host_deck, :tag_client_deck

    def initialize
      @header = ReplayHeader.new

      @host_name = ''
      @client_name = ''
      @start_lp = 8000
      @start_hand = 5

      @draw_count = 1
      @opt = 0
      @host_deck = nil
      @client_deck = nil

      @tag_host_name = nil
      @tag_client_name = nil
      @tag_host_deck = nil
      @tag_client_deck = nil
    end

    def self.read_header(reader)
      header = ReplayHeader.new
      header.id = reader.read_int32
      header.version = reader.read_int32
      header.flag = reader.read_int32
      header.seed = reader.read_int32
      header.data_size_raw = reader.read_byte_array 4
      header.hash = reader.read_int32
      header.props = reader.read_byte_array 8
      header
    end

    def self.read_deck(reader)
      deck = Deck.new
      deck.main = reader.read_next_pack
      deck.ex = reader.read_next_pack
    end

    def self.read_replay(header, reader)
      replay = Replay.new
      replay.header = header
      replay.host_name = reader.read_string 40
      replay.tag_host_name = reader.read_string 40 if replay.header.is_tag?
      replay.tag_client_name = reader.read_string 40 if replay.header.is_tag?
      replay.client_name = reader.read_string 40
      replay.start_lp = reader.read_int32
      replay.start_hand = reader.read_int32
      replay.draw_count = reader.read_int32
      replay.opt = reader.read_int32
      replay.host_deck = read_deck reader
      replay.tag_host_deck = read_deck reader if replay.header.is_tag?
      replay.tag_client_deck = read_deck reader if replay.header.is_tag?
      replay.client_deck = read_deck reader
      Ygoruby.info "Loaded replay #{replay.host_name} vs #{replay.client_name}"
      replay
    end

    def self.from_file(file_path)
      from_string File.open(file_path) {|f| f.read}
    end

    def self.from_string(string)
      reader = ReplayReader.new string
      header = read_header reader
      lzma_string = header.get_lzma_header + reader.read_all
      if header.is_compressed?
        decompressed_string = LZMA.decompress lzma_string
      else
        decompressed_string = lzma_string
      end
      reader = ReplayReader.new decompressed_string
      read_replay header, reader
    end

    def decks
      is_tag? ? [@host_deck, @tag_host_deck, @tag_client_deck, @client_deck] : [@host_deck, @client_deck]
    end

    define_method (:is_tag?) {header.is_tag?}
  end
end