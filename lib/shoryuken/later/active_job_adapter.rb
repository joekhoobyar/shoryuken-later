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

      class << self
        def enqueue_at(job, timestamp) #:nodoc:
          register_worker!(job)

          delay = (timestamp - Time.current.to_f).round
          if delay > 15.minutes
            # The job is scheduled 15 minutes or more for now, so it needs to be
            # warehoused elsewhere until it's ready to be moved over to SQS

            table = Shoryuken::Later.default_table

            Shoryuken::Later::Client.create_item(table, {
              perform_at: Time.current.to_i + delay.to_i,
              shoryuken_queue: job.queue_name,
              shoryuken_class: JobWrapper.to_s,
              shoryuken_args: JSON.dump(body: job.serialize, options: {})
            })
          else
            # The job is scheduled for less than 15 minutes from now, so it
            # can be sent directly to SQS

            Shoryuken::Client.queues(job.queue_name).send_message({
              message_body: job.serialize,
              message_attributes: message_attributes,
              delay_seconds: delay
            })
          end
        end
      end
    end
  end
end
