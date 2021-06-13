require 'time'
require 'json'
require 'pry'

module Shoryuken
  module Later
    module Worker
      module ClassMethods
        def perform_later(time, *body)
          time = Time.now.utc + time.to_i if time.is_a?(Numeric)
          time = time.to_time if time.respond_to?(:to_time)
          raise ArgumentError, 'expected Numeric, Time but got '+time.class.name unless Time===time
          
          # Times that are less than 15 minutes in the future can be queued immediately.
          if time < Time.now.utc + Shoryuken::Later::MAX_QUEUE_DELAY
            enqueue_in(time, body)
          else
            table = get_shoryuken_options['schedule_table'] || Shoryuken::Later.default_table
            args = JSON.dump(body: body)
            client = Shoryuken::Later::Client.new(table)
            client.create(
              perform_at: time.to_i,
              shoryuken_args: args,
              shoryuken_class: self.to_s
            )
          end
        end
      end
    end
  end
  
  Worker::ClassMethods.send :include, Later::Worker::ClassMethods
end