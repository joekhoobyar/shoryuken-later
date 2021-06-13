module Shoryuken
  module Later
    class ItemProcessor
      def self.call(item)
        time, worker_class, args = item.values_at('perform_at','shoryuken_class','shoryuken_args')

        worker_class = worker_class.constantize
        args = JSON.parse(args)
        time = Time.at(time)

        # Conditionally delete an item prior to enqueuing it, ensuring only one actor may enqueue it.
        begin client.delete(item)
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          # Item was already deleted, so it does not need to be queued.
          return
        end

        worker_class.enqueue_in(time, *args['body'])
      end
    end
  end
end
