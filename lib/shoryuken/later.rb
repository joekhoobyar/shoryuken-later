require 'shoryuken'
require 'shoryuken/later/version'
require 'shoryuken/later/client'
require 'shoryuken/later/worker'

module Shoryuken
  module Later
    MAX_QUEUE_DELAY = 15 * 60

    DEFAULT_POLL_DELAY = 5 * 60

    DEFAULTS = {
      aws: {},
      later: {
        tables: [],
        delay: DEFAULT_POLL_DELAY,
      },
      timeout: 8
    }

    @@tables = []
    @@default_table = 'shoryuken_later'
    @@active_job_table_name_prefixing = false

    class << self

      def options
        @options ||= DEFAULTS.dup.tap{|h| h[:later] = h[:later].dup }
      end

      def poll_delay
        options[:later][:delay] || DEFAULT_POLL_DELAY
      end

      def logger
        Shoryuken::Logging.logger
      end

      # Assume whole configuration was loaded, perform extra steps such as prefixing table names
      def process_options
        prefix_table_names
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

      def active_job_table_name_prefixing
        @@active_job_table_name_prefixing
      end

      def active_job_table_name_prefixing=(prefix)
        @@active_job_table_name_prefixing = prefix
      end

      def prefix_table_names
        return unless defined? ::ActiveJob
        return unless Shoryuken::Later.active_job_table_name_prefixing

        # Note : use the same prefix used for the ActiveJob queues, seems legit
        table_name_prefix = ::ActiveJob::Base.queue_name_prefix
        table_name_delimiter = ::ActiveJob::Base.queue_name_delimiter

        # See https://github.com/rails/rails/blob/master/activejob/lib/active_job/queue_name.rb#L27
        Shoryuken::Later.tables.map! do |table_name, weight|
          name_parts = [table_name_prefix, table_name]
          name_parts.compact.join(table_name_delimiter)
        end
      end
    end
  end
end

require 'shoryuken/later/active_job_adapter' if defined?(::ActiveJob)