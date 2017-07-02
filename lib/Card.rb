require 'sqlite3'
require 'yaml'

module Ygoruby
  class Card
    attr_accessor :locale
    attr_reader :id, :ot, :alias, :setcode, :type, :category, :name, :desc
    attr_reader :origin_level, :race, :attribute, :atk, :def

    def read_data(data)
      @id = data[0]
      @ot = data[1]
      @alias = data[2]
      @setcode = data[3]
      @type = data[4]
      @category = data[10]
      @name = data[12]
      @desc = data[13]
      if is_type_monster
        @origin_level = data[7]
        @race = data[8]
        @attribute = data[9]
        @atk = data[5]
        @def = data[6]
      end
    end

    define_method(:is_alias) {@alias > 0}
    define_method(:is_ocg) {@ot & 1 > 0}
    define_method(:is_tcg) {@ot & 2 > 0}
    define_method(:is_ex) {is_type_synchro or is_type_xyz or is_type_funsion or is_type_link}
    define_method(:level) {@origin_level % 65536}
    define_method(:pendulum_scale) {is_type_pendulum ? (@origin_level - (@origin_level % 65536)) / 65536 / 257 : -1}
    define_method(:link_markers) {sprintf('%09b', @def).scan(/\d/).reverse.map {|s| s == '1'}}
    define_method(:link_number) { level }

    def to_s
      "[#{@locale} Card] [#{@id}] #{@name}"
    end
  end
end