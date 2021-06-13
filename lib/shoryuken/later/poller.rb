require 'json'
require 'pry'

module Shoryuken
  module Later
    class Poller
      include Shoryuken::Util
      
      attr_reader :table_name
      
      def initialize(table_name)
        @table_name = table_name
      end
      
      def poll
        started_at = Time.now
        logger.debug { "Polling for scheduled messages in '#{table_name}'" }

        begin
          while items = client.batch
            items.each do |item|
              id = item['id']
              logger.info "Found message #{id} from '#{table_name}'"
              if sent_msg = ItemProcessor.call(item)
                logger.debug { "Enqueued message #{id} from '#{table_name}'" }
              else
                logger.debug { "Skipping already queued message #{id} from '#{table_name}'" }
              end
            end
          end

          logger.debug { "Poller for '#{table_name}' completed in #{elapsed(started_at)} ms" }
        rescue => ex
          logger.error "Error fetching message: #{ex}"
          logger.error ex.backtrace.first
        end
      end

      private
    
      def client
        @client ||= Shoryuken::Later::Client.new(table_name)
      end
    end
  end
end
