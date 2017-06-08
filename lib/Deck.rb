require "#{File.dirname __FILE__}/Card.rb"
module Ygoruby
  class Deck
    attr_accessor :main
    attr_accessor :ex
    attr_accessor :side

    attr_accessor :main_classified
    attr_accessor :ex_classified
    attr_accessor :side_classified

    attr_accessor :cards_classified

    def initialize
      @main = []
      @ex = []
      @side = []
    end

    DECK_FILE_HEAD = "#created by lib."
    DECK_FILE_MAIN_FLAG = "#main"
    DECK_FILE_EX_FLAG = "#extra"
    DECK_FILE_SIDE_FLAG = "!side"
    DECK_FILE_NEWLINE = "\n"

    def save_ydk(file_name)
      file = File.open(file_name, "w")
      file.write DECK_FILE_HEAD + DECK_FILE_NEWLINE
      file.write DECK_FILE_MAIN_FLAG + DECK_FILE_NEWLINE
      self.main.each {|card| file.write card.to_s + DECK_FILE_NEWLINE}
      file.write DECK_FILE_EX_FLAG + DECK_FILE_NEWLINE
      self.ex.each {|card| file.write card.to_s + DECK_FILE_NEWLINE}
      file.write DECK_FILE_SIDE_FLAG + DECK_FILE_NEWLINE
      self.side.each {|card| file.write card.to_s + DECK_FILE_NEWLINE}
      file.close
    end

    def self.load_ydk(file_path)
      deck = Deck.new
      file = File.open file_path
      deck.load_ydk_line file.readline.chomp until file.eof?
      file.close
      deck.classify
      deck
    end

    def load_ydk_line(line)
      return if line == nil or line == "" or line.start_with? "#"
      line.strip!
      if line == DECK_FILE_MAIN_FLAG
        @pointer = @main
      elsif line == DECK_FILE_EX_FLAG
        @pointer = @ex
      elsif line == DECK_FILE_SIDE_FLAG
        @pointer = @side
      else
        @pointer.push line.to_i
      end
    end

    def self.load_ydk_from_str(str)
      lines = str.split "\n"
      deck = Deck.new
      lines.each {|line| deck.load_ydk_line line}
      deck.classify
      deck
    end

    def to_hash
      {
          main: @main,
          side: @side,
          ex: @ex
      }
    end

    def to_json(*args)
      to_hash.to_json
    end

    def self.from_hash(hash)
      return nil if hash == nil
      answer = Deck.allocate
      answer.main = hash["main"] || []
      answer.side = hash["side"] || []
      answer.ex = hash["ex"] || []
      answer.classify
      answer
    end

    def inspect
      to_hash.inspect
    end

    def classify
      self.main_classified = classify_pack self.main
      self.ex_classified = classify_pack self.ex
      self.side_classified = classify_pack self.side
      self.cards_classified = classify_pack self.main + self.ex + self.side
    end

    def classify_pack(pack)
      hash = {}
      return {} if pack == nil
      for card in pack
        if hash[card] == nil
          hash[card] = 1
        else
          hash[card] += 1
        end
      end
      hash
    end

    # def check_alias
    #   check_pack_alias self.main
    #   check_pack_alias self.side
    #   check_pack_alias self.ex
    # end

    # def check_pack_alias(pack)
    #   alias_list = Card.alias_list
    #   pack.replace pack.map {|id| alias_list.has_key?(id) ? alias_list[id] : id}
    # end

    def separate_ex_from_main(environment)
      new_main = []
      new_ex = []
      @main.each do |card_id|
        card = environment[card_id]
        if card.nil?
          new_main.push card_id
        else
          (card.is_ex? ? new_ex : new_main).push card_id
        end
      end
      @main = new_main
      @ex = new_ex
    end
  end
end
