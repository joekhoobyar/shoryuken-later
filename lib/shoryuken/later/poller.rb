require 'json'

module Shoryuken
  module Later
    class Poller
      #include Celluloid
      include Shoryuken::Util

    private
    
      def next_item(table)
        Shoryuken::Later::Client.tables(table).items.
          where(:perform_at).less_than((Time.now + Shoryuken::Later::MAX_QUEUE_DELAY).to_i).
          first
      end
    
      def process_item(item)
        time, worker_class, args, id = item.attributes.values_at('perform_at','shoryuken_class','shoryuken_args','id')
        
        worker_class = worker_class.constantize
        args = JSON.parse(args)
        time = Time.at(time)
        
        # Conditionally delete an item prior to enqueuing it, ensuring only one actor may enqueue it.
        begin item.delete(:if => {id: id})
        rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => e
          # Item was already deleted, so it does not need to be queued.
          return
        end

        # Now the item is safe to be enqueued, since the conditional delete succeeded.
        worker_class.perform_in(time, args['body'], args['options'])
      end

    end
  end
end
