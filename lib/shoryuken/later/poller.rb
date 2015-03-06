require 'json'

module Shoryuken
  module Later
    class Poller
      include Celluloid
      include Shoryuken::Util
      
      attr_reader :table_name
      
      def initialize(manager, table_name)
        @manager = manager
        @table_name = table_name
        
        @manager.async.poller_ready(@table_name, self)
      end
      
      def poll
        watchdog('Later::Poller#poll died') do
          started_at = Time.now
          
          logger.debug { "Polling for scheduled messages in '#{@table_name}'" }
          
          begin
            while item = next_item
              id = item.attributes['id']
              logger.info "Found message #{id} from '#{@table_name}'"
              defer do
                if sent_msg = process_item(item)
                  logger.debug { "Enqueued message #{id} from '#{@table_name}' as #{sent_msg.id}" }
                else
                  logger.debug { "Skipping already queued message #{id} from '#{@table_name}'" }
                end
              end
            end
  
            logger.debug { "Poller for '#{@table_name}' completed in #{elapsed(started_at)} ms" }
          rescue => ex
            logger.error "Error fetching message: #{ex}"
            logger.error ex.backtrace.first
          end
            
          @manager.async.poller_done(@table_name, self)
        end
      end

    private
    
      def table
        Shoryuken::Later::Client.tables(@table_name)
      end

      # Fetches the next available item from the schedule table.    
      def next_item
        table.items.where(:perform_at).less_than((Time.now + Shoryuken::Later::MAX_QUEUE_DELAY).to_i).first
      end
    
      # Processes an item and enqueues it (unless another actor has already enqueued it).
      def process_item(item)
        time, worker_class, args, id = item.attributes.values_at('perform_at','shoryuken_class','shoryuken_args','id')
        
        worker_class = worker_class.constantize
        args = JSON.parse(args)
        time = Time.at(time)
        queue_name = item.attributes['shoryuken_queue']
        
        # Conditionally delete an item prior to enqueuing it, ensuring only one actor may enqueue it.
        begin item.delete(:if => {id: id})
        rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => e
          # Item was already deleted, so it does not need to be queued.
          return
        end

        # Now the item is safe to be enqueued, since the conditional delete succeeded.
        body, options = args.values_at('body','options')
        if queue_name.nil?
          worker_class.perform_in(time, body, options)
          
        # For compatibility with Shoryuken's ActiveJob adapter, support an explicit queue name.
        else
          delay = (time - Time.now).to_i
          options[:delay_seconds] = delay if delay > 0
          options[:message_attributes] ||= {}
          options[:message_attributes]['shoryuken_class'] = { string_value: worker_class.to_s, data_type: 'String' }
          Shoryuken::Client.send_message(queue_name, body, options)
        end
      end

    end
  end
end
