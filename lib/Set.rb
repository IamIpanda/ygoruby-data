module Ygoruby
  class Set

    attr_accessor :locale
    attr_accessor :name
    attr_accessor :origin_name
    attr_accessor :code
    attr_accessor :ids

    def initialize(code, name, locale = '')
      @code = code
      @name = name
      @locale = locale
      separate_origin_name_from_name
    end

    def separate_origin_name_from_name
      names = @name.split "\t"
      return false if names.length <= 1
      @origin_name = names[1]
      @name = names[0]
      true
    end

    def [](id)
      includes id
    end

    def includes(id)
      load_ids if @ids == nil
      id = id.id if id.is_a? Ygoruby::Card
      @ids.include? id
    end

    def to_s
      "[#{locale} Set] [0x#{@code.to_s(16)}] #{name} " + (@origin_name.nil? ? '' : "(#{@origin_name})") + (@ids.nil? ? 'no card' : " (#{@ids.count} cards)")
    end
  end
end