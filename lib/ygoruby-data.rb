# Entrance file.

module Ygoruby
  class << self
    attr_accessor :locale_path
    attr_accessor :lua_path
  end
end

Ygoruby.locale_path = File.dirname(__FILE__) + '/../ygopro-database/locales'
Ygoruby.lua_path = File.dirname(__FILE__) + '/Constant.lua'

require File.dirname(__FILE__) + '/Log.rb'
require File.dirname(__FILE__) + '/Card.rb'
require File.dirname(__FILE__) + '/Deck.rb'
require File.dirname(__FILE__) + '/Set.rb'
require File.dirname(__FILE__) + '/Environment.rb'
require File.dirname(__FILE__) + '/Replay.rb'
