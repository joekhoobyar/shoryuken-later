# Build on top of Shoryuken's ActiveJob adapter.

# @see ActiveJob::QueueAdapter::ShoryukenAdapter

# ActiveJob docs: http://edgeguides.rubyonrails.org/active_job_basics.html
# Example adapters ref: https://github.com/rails/rails/tree/master/activejob/lib/active_job/queue_adapters

require 'shoryuken-later'
require 'shoryuken/extensions/active_job_adapter'

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
      JobWrapper = ShoryukenAdapter::JobWrapper

      # This will override Shoryuken Adapter's enqueue_at to use Shoryuken::Later when possible
      # - When the wait is > 15 minutes, delegate to Shoryuken::Later
      #   - In that case it will use either job.table_name or fallback job.queue_name for the DynamoDB table
      # - Otherwise fall back to Shoryuken (super)
      def enqueue_at(job, timestamp) #:nodoc:
        register_worker!(job)

        delay = (timestamp - Time.current.to_f).round
        if delay > 15.minutes
          Shoryuken::Later::Client.create_item(
            job.respond_to?(:table_name?) ? job.table_name : job.queue_name,
            perform_at: Time.current.to_i + delay.to_i,
            shoryuken_queue: job.queue_name, shoryuken_class: JobWrapper.to_s,
            shoryuken_args: JSON.dump(body: job.serialize, options: {})
          )
        else
          super
        end
      end
    end
  end
end
