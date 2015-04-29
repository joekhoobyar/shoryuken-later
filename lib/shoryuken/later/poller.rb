require 'json'

module Shoryuken
  module Later
    class Poller
      include Shoryuken::Util

      attr_reader :table_name

      def initialize(table_name)
        @table_name = table_name
      end

      def poll
        watchdog('Later::Poller#poll died') do
          started_at = Time.now

          logger.debug { "Polling for scheduled messages in '#{table_name}'" }

          items = client.items(table_name)

          logger.info "Found #{items.count} message from '#{table_name}'"

          items.each_slice(10) do |batch_items|
            process_items(batch_items)
          end
        end
      end

    private

      def client
        Shoryuken::Later::Client
      end

      def process_items(items)
        entries = preprocess_items(items)

        # Enqueue the batch of messages for viable items
        if entries.count > 0
          Shoryuken::Client.queues(queue_name).send_messages(entries)
        end

        logger.debug { "Enqueued #{entries.count} of #{items.count} messages from '#{table_name}'" }
      end

      # Returns a set of message options (entities) that can be enqueued
      def preprocess_items(items)
        items.map{ |item| preprocess_item(item) }.compact
      end

      # Pre-processes an item (unless another actor has already enqueued it),
      # preparing it to get enqueued.
      def preprocess_item(item)
        time, worker_class, args, id = item.values_at('perform_at','shoryuken_class','shoryuken_args','id')

        worker_class = worker_class.constantize
        args = JSON.parse(args)
        time = Time.at(time)
        queue_name = item['shoryuken_queue']

        # Conditionally delete an item prior to enqueuing it, ensuring only one actor may enqueue it.
        begin client.delete_item table_name, item
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          # Item was already deleted, so it does not need to be queued.
          return
        end

        # Now the item is safe to be enqueued, since the conditional delete succeeded.
        body, options = args.values_at('body','options')
        if queue_name.nil?
          worker_class.perform_in(time, body, options)

          return
        # For compatibility with Shoryuken's ActiveJob adapter, support an explicit queue name.
        else
          delay = (time - Time.now).to_i
          body = JSON.dump(body) if body.is_a? Hash
          options[:delay_seconds] = delay if delay > 0
          options[:message_body] = body
          options[:message_attributes] ||= {}
          options[:message_attributes]['shoryuken_class'] = { string_value: worker_class.to_s, data_type: 'String' }

          return options
        end
      end
    end
  end
end
