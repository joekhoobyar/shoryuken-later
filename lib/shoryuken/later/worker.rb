require 'time'

module Shoryuken
  module Later
    module Worker
      module ClassMethods
        
        def perform_later(time, body, options = {})
          time = Time.now + time.to_i if Numeric===time
          time = time.to_time if time.respond_to?(:to_time)
          raise ArgumentError, 'expected Numeric, Time but got '+time.class.name unless Time===time
          
          # Times that are less than 15 minutes in the future can be queued immediately.
          if time < Time.now + 15 * 60
            perform_in(time, body, options)
            
          # Otherwise, the message is inserted into a DynamoDB table with the same name as the queue.
          else
            table = get_shoryuken_options['schedule_table'] || 'shoryuken_later'
            args = JSON.dump(body: body, options: options)
            Shoryuken::Later::Client.put_item(table, perform_at: time.to_i, shoryuken_args: args,
                                                     shoryuken_class: self.to_s)
          end
        end
      end
    end
  end
  
  Worker::ClassMethods.send :include, Later::Worker::ClassMethods
end