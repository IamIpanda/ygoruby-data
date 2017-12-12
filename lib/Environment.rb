require File.dirname(__FILE__) + '/Card.rb'
require File.dirname(__FILE__) + '/Set.rb'
require File.dirname(__FILE__) + '/Log.rb'

module Ygoruby
  class Environment
    # SQL 卡片查询指令
    READ_DATA_SQL = 'select * from datas join texts on datas.id == texts.id where datas.id == (?)'
    READ_ALL_DATA_SQL = 'select * from datas join texts on datas.id == texts.id'
    # SQL 系列查询指令
    QUERY_SET_SQL = 'select id from datas where (setcode & 0x0000000000000FFF == (?) or setcode & 0x000000000FFF0000 == (?) or setcode & 0x00000FFF00000000 == (?) or setcode & 0x0FFF000000000000 == (?))'
    QUERY_SUBSET_SQL = 'select id from datas where (setcode & 0x000000000000FFFF == (?) or setcode & 0x00000000FFFF0000 == (?) or setcode & 0x0000FFFF00000000 == (?) or setcode & 0xFFFF000000000000 == (?))'
    # SQL 卡片查询指令
    SEARCH_NAME_SQL = 'select id from texts where name like (?)'

    attr_accessor :attributes
    attr_accessor :races
    attr_accessor :types
    attr_accessor :sets
    attr_accessor :locale
    attr_reader :cards

    def initialize(locale)

      path = File.join Ygoruby.locale_path, "/#{locale}"
      unless Dir.exist? path
        Ygoruby.warn "Card Environment can't find #{locale} path."
        return nil
      end

      @cards = {}
      @locale = locale
      @dbs = search_cdb locale

      @attribute_names = []
      @race_names = []
      @type_names = []

      @attributes = []
      @races = []
      @types = []
      @sets = []

      load_strings_file File.join Ygoruby.locale_path, "/#{locale}/strings.conf"
      link_strings_and_constants
      link_setname_to_sql

      Environment.environments[locale] = self
    end

    def search_cdb(locale)
      db_path = Dir.glob File.join(Ygoruby.locale_path, "/#{locale}/*.cdb")
      Ygoruby.info "Card environment #{locale} loading #{db_path.count} cdb(s) from #{Ygoruby.locale_path}"
      db_path.map {|path| SQLite3::Database.new path}
    end

    class << self
      attr_accessor :attribute_constants
      attr_accessor :race_constants
      attr_accessor :type_constants
      attr_accessor :environments

      def initialize
        @environments = {}

        @attribute_constants = []
        @race_constants = []
        @type_constants = []

        load_lua_file Ygoruby.lua_path
        register_methods
      end

      def load_lua_file(file_path)
        load_lua_lines File.open(file_path) {|file| file.read}
      end

      def load_lua_lines(string_file)
        lines = string_file.split "\n"
        lines.each do |line|
          name, value = load_lua_line_pattern line
          next if name == nil
          check_and_add_constant name, value, 'ATTRIBUTE_', @attribute_constants
          check_and_add_constant name, value, 'RACE_', @race_constants
          check_and_add_constant name, value, 'TYPE_', @type_constants
        end
        # 种族中第一行包含一个「ALL」
        # @race_constants = @race_constants[1..-1]
      end

      def load_lua_line_pattern(line)
        answer = line[/([A-Z_]+)\s*=\s*0x(\d+)/]
        return ['', 0] if answer == nil
        [$1, $2.hex]
      end

      def check_and_add_constant(name, value, prefix, target)
        return unless name.start_with? prefix
        target.push({name: name[prefix.length..-1].downcase, value: value})
      end

      def register_methods
        register_typed_methods 'attribute', @attribute_constants
        register_typed_methods 'race', @race_constants
        register_typed_methods 'type', @type_constants
      end

      def register_typed_methods(prefix, items)
        prefix.downcase!
        items.each do |item|
          method_name = ('is_' + prefix + '_' + item[:name].downcase).to_sym
          Ygoruby::Card.instance_eval do
            define_method(method_name) {eval('@' + prefix) & item[:value] > 0}
          end
        end
      end

      def [](locale)
        if @environments.key? locale
          @environments[locale]
        else
          environment = Environment.new locale
          environment.locale == nil ? nil : environment
        end
      end

      def valid_locale_list
        Dir.entries(Ygoruby.locale_path) - ['.', '..', '.DS_Store']
      end
    end

    Environment.initialize

    def load_strings_file(file_path)
      load_strings_lines File.open(file_path) {|file| file.read}
    end

    def load_strings_lines(string_file)
      lines = string_file.split "\n"
      lines.each do |line|
        if line.start_with? '!system 10'
          system_number, text = load_strings_line_pattern line
          @attribute_names.push text if is_attribute_name? system_number
          @race_names.push text if is_race_name? system_number
          @type_names.push text if is_type_name? system_number
        elsif line.start_with? '!setname'
          set_code, set_name = load_setname_line_pattern line
          @sets.push Set.new set_code, set_name, @locale
        end
      end
    end

    def load_strings_line_pattern(line)
      reg = /!system (\d+) (.+)/
      answer = line[reg]
      return [0, ''] if answer == nil
      [$1.to_i, $2]
    end

    def load_setname_line_pattern(line)
      reg = /!setname 0x([0-9a-fA-F]+) (.+)/
      answer = line[reg]
      return [0, ''] if answer == nil
      [$1.hex, $2]
    end

    define_method(:is_attribute_name?) {|system_number| 1010 <= system_number and system_number < 1020}
    define_method(:is_race_name?) {|system_number| 1020 <= system_number and system_number < 1050}
    define_method(:is_type_name?) {|system_number| 1050 <= system_number and system_number < 1080 and system_number != 1053 and system_number != 1065}

    def link_strings_and_constants
      link_strings_and_constants_pattern @attribute_names, Environment.attribute_constants, @attributes
      link_strings_and_constants_pattern @race_names, Environment.race_constants, @races
      link_strings_and_constants_pattern @type_names, Environment.type_constants, @types

      Ygoruby.info "Card environment #{@locale} loaded #{@attributes.length} attributes."
      Ygoruby.info "Card environment #{@locale} loaded #{@races.length} races."
      Ygoruby.info "Card environment #{@locale} loaded #{@types.length} types."
    end

    def link_strings_and_constants_pattern(strings, constants, target)
      target.clear
      for i in 0...strings.length
        constant = constants[i]
        next if constant == nil
        target.push({name: constant[:name], value: constant[:value], text: strings[i]})
      end
    end

    def link_setname_to_sql
      for set in @sets
        ids = []
        @dbs.each {|db| ids += Environment.get_ids_by_set_code(db, set.code)}
        set.ids = ids
        Ygoruby.debug "Set loaded: #{set.to_s}"
      end
      Ygoruby.info "Card environment #{@locale} loaded #{@sets.length} sets."
    end

    def self.get_ids_by_set_code(database, set_code)
      sql_query = set_code < 0xFF ? QUERY_SET_SQL : QUERY_SUBSET_SQL
      stmt = database.prepare sql_query
      result = stmt.execute set_code, set_code << 8, set_code << 16, set_code << 24
      return [] if result == nil
      ids = []
      until result.eof?
        result_row = result.next
        ids.push(result_row[0]) if result_row != nil
      end
      ids
    end

    def race_name(card)
      @races.each do |race|
        return race[:text] if card.race & race.value > 0
      end
      ''
    end

    def attribute_name(card)
      @attributes.each do |attribute|
        return attribute[:text] if card.attribute & attribute.value > 0
      end
      ''
    end

    def get_card_by_id(id)
      return @cards[id] if @cards[id]
      generate_card_by_id id
    end

    def generate_card_by_id(id)
      for db in @dbs
        card = try_generate_card_by_id db, id
        return card if card != nil
      end
      Ygoruby.warn "Card environment #{locale} can't find card [id = #{id}], #{@dbs.count} database searched."
      nil
    end

    def try_generate_card_by_id(database, id)
      stmt = database.prepare READ_DATA_SQL
      result = stmt.execute id
      data = result.next
      return nil if data == nil
      card = Ygoruby::Card.new
      card.read_data data
      card.locale = @locale
      @cards[card.id] = card
      card
    end

    def load_all_cards
      Ygoruby.info "Card environment #{@locale} is loading all cards. Origin cache #{@cards.count} cards is cleared."
      @cards.clear
      @dbs.each {|db| load_all_cards_from_database db}
    end

    def load_all_cards_from_database(database)
      result = database.execute READ_ALL_DATA_SQL
      count = 0
      result.each do |data|
        card = Ygoruby::Card.new
        card.read_data data
        card.locale = @locale
        @cards[card.id] = card
        count += 1
      end
      Ygoruby.info("Card environment #{@locale} loaded #{count} cards from a database.")
    end

    def [](card_id)
      return @cards[card_id] if @cards.key? card_id
      generate_card_by_id card_id
    end

    def to_s
      "[#{@locale} Card Environment]"
    end
  end
end