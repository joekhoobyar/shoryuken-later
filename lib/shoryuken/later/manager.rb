require 'set'
require 'shoryuken/later/poller'

module Shoryuken
  module Later
    class Manager
      include Celluloid
      include Shoryuken::Util
      
      trap_exit :poller_died
      
      def initialize
        @tables = Shoryuken::Later.tables.dup.uniq
        
        @done = false
        
        @idle = Set.new([])
        @busy = Set.new([])
        @timers = Hash.new
        
        @tables.each{|table| spawn_poller(table) }
      end

      def start
        logger.info 'Starting'

        # Start a timer for every table being polled.
        @tables.each do |table|
          
          # Save the timer so it can be cancelled at shutdown.
          @timers[table] = every(Shoryuken::Later.poll_delay) do
            name = :"poller-#{table}"
            
            # Only start polling if the poller is idle.
            if @idle.include? name
              @idle.delete(name)
              @busy << name
              
              Actor[name].async.poll
            end
          end
        end
      end

      def stop(options = {})
        watchdog('Later::Manager#stop died') do
          @done = true
          
          @timers.each_value{|timer| timer.cancel if timer }

          logger.info { "Shutting down #{@idle.size} idle poller(s)" }

          @idle.each do |name|
            poller = Actor[name] and poller.alive? and poller.terminate
          end
          @idle.clear

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
          logger.debug { "Poller done for '#{table}'" }

          @busy.delete poller.name

          if stopped?
            poller.terminate if poller.alive?
          else
            @idle << poller.name
          end
        end
      end

      def poller_died(poller, reason)
        watchdog('Later::Manager#poller_died died') do
          table = poller.name.gsub(/^poller-/,'')
          
          logger.debug { "Poller for '#{table}' died, reason: #{reason}" }

          @busy.delete poller.name

          spawn_poller table unless stopped?
        end
      end

      def stopped?
        @done
      end

      private
      
      def spawn_poller(table)
        poller = Poller.new_link(current_actor, table)
        Actor[:"poller-#{table}"] = poller
        @idle << poller.name
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
