module Ygoruby

end

unless Ygoruby.methods.include?(:logger)
  require 'logger'
  module Ygoruby
    class << self
      attr_accessor :logger
    end
  end

  Ygoruby.logger = Logger.new(STDERR)
  Ygoruby.logger.level = :info
end

unless Ygoruby.methods.include?(:warn)
  module Ygoruby
    class << self
      define_method(:debug) {|msg| logger.debug msg if logger != nil}
      define_method(:info) {|msg| logger.info msg if logger != nil}
      define_method(:warn) {|msg| logger.warn msg if logger != nil}
      define_method(:fatal) {|msg| logger.fatal msg if logger != nil}
      define_method(:error) {|msg| logger.error msg if logger != nil}
    end
  end
end
