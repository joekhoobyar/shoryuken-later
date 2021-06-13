require 'shoryuken'
require 'shoryuken/later/version'
require 'shoryuken/later/client'
require 'shoryuken/later/worker'
require 'shoryuken/later/item_processor'

module Shoryuken
  module Later
    MAX_QUEUE_DELAY = 15 * 60
    
    DEFAULT_POLL_DELAY = 10
    
    DEFAULTS = {
      aws: {},
      later: {
        tables: [],
        delay: DEFAULT_POLL_DELAY,
      },
      timeout: 8
    }
    
    @@tables = ['shoryuken_later']
    @@default_table = 'shoryuken_later'
    
    class << self
      def options
        @options ||= DEFAULTS.dup.tap{ |h| h[:later] = h[:later].dup }
      end
      
      def poll_delay
        options[:later][:delay] || DEFAULT_POLL_DELAY
      end
      
      def default_table
        @@default_table
      end
      
      def default_table=(table)
        @@default_table = table
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
