# All of this has been "borrowed" from Shoryuken.

# @see Shoryuken::Launcher
module Shoryuken
  module Later
    class Launcher
      include Celluloid
      include Shoryuken::Util

      trap_exit :actor_died

      attr_accessor :manager
      
      def initialize
        @condvar = Celluloid::Condition.new
        @manager = Shoryuken::Later::Manager.new_link(@condvar)

        @done = false
      end

      def stop(options = {})
        watchdog('Later::Launcher#stop') do
          @done = true

          manager.async.stop(shutdown: !!options[:shutdown], timeout: Shoryuken::Later.options[:timeout])
          @condvar.wait
          manager.terminate
        end
      end

      def run
        watchdog('Later::Launcher#run') do
          manager.async.start
        end
      end

      def actor_died(actor, reason)
        return if @done
        logger.warn 'Shoryuken::Later died due to the following error, cannot recover, process exiting'
        exit 1
      end
    end
  end
end
