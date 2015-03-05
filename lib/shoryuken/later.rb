require 'shoryuken'
require 'shoryuken/later/version'
require 'shoryuken/later/client'
require 'shoryuken/later/worker'

module Shoryuken
  module Later
    MAX_QUEUE_DELAY = 15 * 60
    
    DEFAULTS = {
      aws: {},
      later: {
        tables: ['shoryuken_later'],
        delay: 5 * 60,
      },
      timeout: 8
    }
    
    @@tables = []
    
    class << self
      def options
        @options ||= DEFAULTS.dup
      end
      
      def tables
        @@tables
      end
    
      def logger
        Shoryuken::Logging.logger
      end
    end
  end
end