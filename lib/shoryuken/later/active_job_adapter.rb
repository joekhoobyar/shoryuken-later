# Build on top of Shoryuken's ActiveJob adapter.

# @see ActiveJob::QueueAdapter::ShoryukenAdapter

# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

require 'shoryuken-later'

module ActiveJob
  module QueueAdapters
    # == Shoryuken::Later adapter for Active Job
    #
    # Shoryuken ("sho-ryu-ken") is a super-efficient AWS SQS thread based message processor.
    # Shoryuken::Later allows messages to be delayed arbitrarily far into the future.
    #
    # Read more about Shoryuken {here}[https://github.com/phstc/shoryuken].
    # Read more about Shoryuken::Later {here}[https://github.com/joekhoobyar/shoryuken-later].
    #
    # To use Shoryuken::Later set the queue_adapter config to +:shoryuken_later+.
    #
    #   Rails.application.config.active_job.queue_adapter = :shoryuken_later
    class ShoryukenLaterAdapter < ShoryukenAdapter
      class << self
        def enqueue_at(job, timestamp) #:nodoc:
          register_worker!(job)

          delay = (timestamp - Time.current.to_f).round
          if delay > 15.minutes
            Shoryuken::Later::Client.put_item(Shoryuken::Later.default_table, perform_at: delay.to_i,
                                                                              shoryuken_queue: job.queue_name, shoryuken_class: JobWrapper.to_s,
                                                                              shoryuken_args: JSON.dump(body: job.serialize, options: {}))
          else
            Shoryuken::Client.send_message(job.queue_name, job.serialize, delay_seconds: delay,
                                                                          message_attributes: message_attributes)
          end
        end
      end
    end
  end
end
