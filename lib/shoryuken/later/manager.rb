require 'set'
require 'shoryuken/later/poller'

module Shoryuken
  module Later
    class Manager
      include Celluloid
      include Shoryuken::Util
      
      def initialize
        @tables = Shoryuken::Later.tables.dup.uniq
        
        @done = false
        
        @idle = Set.new([])
        @busy = Set.new([])
        @timers = {}
        
        @tables.each{|table| Poller.supervise_as :"poller-#{table}", current_actor, table }
      end

      def start
        logger.info 'Starting'

        # Start a poller for every table being polled.
        @tables.each do |table|
          dispatch table
          
          # Save the timer so it can be cancelled at shutdown.
          @timers[table] = every(Shoryuken::Later.poll_delay) { dispatch table }
        end
      end

      def stop(options = {})
        watchdog('Later::Manager#stop died') do
          @done = true
          
          @timers.each_value{|timer| timer.cancel if timer }
          @timers.clear

          logger.info { "Shutting down #{@idle.size} idle poller(s)" }

          @idle.each do |name|
            poller = Actor[name] and poller.alive? and poller.terminate
          end
          @idle.clear

          if @busy.empty?
            return after(0) { signal(:shutdown) }
          end

          if options[:shutdown]
            hard_shutdown_in(options[:timeout])
          else
            soft_shutdown(options[:timeout])
          end
        end
      end

      def poller_done(table, poller)
        watchdog('Later::Manager#poller_done died') do
          logger.debug { "Poller done for '#{table}'" }

          name = :"poller-#{table}"
          @busy.delete name

          if stopped?
            poller.terminate if poller.alive?
          else
            @idle << name
          end
        end
      end

      def poller_ready(table, poller)
        watchdog('Later::Manager#poller_ready died') do
          logger.debug { "Poller for '#{table}' ready" }

          @idle << :"poller-#{table}"
        end
      end

      def stopped?
        @done
      end

      private
      
      def dispatch(table)
        name = :"poller-#{table}"
        
        # Only start polling if the poller is idle.
        if ! stopped? && @idle.include?(name)
          @idle.delete(name)
          @busy << name
              
          Actor[name].async.poll
        end
      end
      
      def soft_shutdown(delay)
        logger.info { "Waiting for #{@busy.size} busy pollers" }

        if @busy.size > 0
          after(delay) { soft_shutdown(delay) }
        else
          after(0) { signal(:shutdown) }
        end
      end

      def hard_shutdown_in(delay)
        logger.info { "Waiting for #{@busy.size} busy pollers" }
        logger.info { "Pausing up to #{delay} seconds to allow pollers to finish..." }

        after(delay) do
          watchdog("Later::Manager#hard_shutdown_in died") do
            if @busy.size > 0
              logger.info { "Hard shutting down #{@busy.size} busy pollers" }

              @busy.each do |busy|
                if poller = Actor[busy]
                  t = poller.bare_object.actual_work_thread
                  t.raise Shutdown if poller.alive?
                end
              end
            end
            after(0) { signal(:shutdown) }
          end
        end
      end
    end
  end
end
