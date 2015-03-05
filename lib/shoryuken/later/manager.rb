require 'shoryuken/later/poller'

module Shoryuken
  module Later
    class Manager
      include Celluloid
      include Shoryuken::Util
      
      def initialize
        @tables = Shoryuken::Later.tables.dup.uniq
        
        @done = false
        
        @ready = @tables.map{|table| :"poller-#{table}" }
        @busy = []
        
        @tables.each do |name|
          Poller.supervise_as(:"poller-#{table}", current_actor, table)
        end
      end

      def start
        logger.info 'Starting'

        dispatch
      end

      def stop(options = {})
        watchdog('Later::Manager#stop died') do
          @done = true

          logger.info { "Shutting down #{@ready.size} quiet poller(s)" }

          @ready.each do |name|
            poller = Actor[name] and poller.alive? and poller.terminate
          end
          @ready.clear

          return after(0) { signal(:shutdown) } if @busy.empty?

          if options[:shutdown]
            hard_shutdown_in(options[:timeout])
          else
            soft_shutdown(options[:timeout])
          end
        end
      end

      def poller_done(table, poller)
        watchdog('Later::Manager#poller_done died') do
          logger.info "Poller done for '#{table}'"

          @busy.delete poller.name

          if stopped?
            poller.terminate if poller.alive?
          else
            @ready << poller.name
          end
        end
      end

      def poller_died(poller, reason)
        watchdog("Later::Manager#poller_died died") do
          logger.info "Process died, reason: #{reason}"

          @busy.delete poller

          unless stopped?
            @ready << Poller.new_link(current_actor, poller.table_name)
          end
        end
      end

      def stopped?
        @done
      end

      def dispatch
        return if stopped?

        logger.debug { "Ready: #{@ready.size}, Busy: #{@busy.size}, Polled Tables: #{@tables.keys.join(', ')}" }

        if @ready.empty?
          logger.debug { 'Pausing fetcher, because all processors are busy' }

          after(1) { dispatch }

          return
        end
      end

      private
      
      def soft_shutdown(delay)
        logger.info { "Waiting for #{@busy.size} busy workers" }

        if @busy.size > 0
          after(delay) { soft_shutdown(delay) }
        else
          after(0) { signal(:shutdown) }
        end
      end

      def hard_shutdown_in(delay)
        logger.info { "Waiting for #{@busy.size} busy workers" }
        logger.info { "Pausing up to #{delay} seconds to allow workers to finish..." }

        after(delay) do
          watchdog("Later::Manager#hard_shutdown_in died") do
            if @busy.size > 0
              logger.info { "Hard shutting down #{@busy.size} busy workers" }

              @busy.each do |poller|
                t = poller.bare_object.actual_work_thread
                t.raise Shutdown if poller.alive?
              end
            end

            after(0) { signal(:shutdown) }
          end
        end
      end
    end
  end
end
