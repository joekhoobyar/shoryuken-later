# Most of this has been "borrowed" from Shoryuken.

# @see Shoryuken::CLI
$stdout.sync = true

require 'singleton'
require 'optparse'
require 'erb'
require 'shoryuken/later'
require 'shoryuken/later/poller'
require 'timers'
require 'aws-sdk-dynamodb'

module Shoryuken
  module Later
    class CLI
      include Shoryuken::Util
      include Singleton

      def run(args)
        @self_read, @self_write = IO.pipe

        %w[INT TERM USR1 USR2].each do |sig|
          trap sig do
            @self_write.puts(sig)
          end
        end

        setup_options(args) do |cli_options|
          # this needs to happen before configuration is parsed, since it may depend on Rails env
          load_rails if cli_options[:rails]
        end
        initialize_logger
        require_workers
        validate!
        daemonize
        write_pid
        
        Shoryuken::Logging.with_context '[later]' do
          logger.info 'Starting'
          start
        end
      end
      
      protected
      
      def poll_tables
        logger.debug "Polling schedule tables"
        @pollers.each do |poller|
          poller.poll
        end
        logger.debug "Polling done"
      end

      private
      
      def start
        # Initialize the timers and poller.
        @timers = Timers::Group.new
        @pollers = Shoryuken::Later.tables.map{ |tbl| Poller.new(tbl) }
          
        begin
          # Poll for items on startup, and every :poll_delay
          poll_tables
          @timers.every(Shoryuken::Later.poll_delay) { poll_tables }
          
          # Loop watching for signals and firing off of timers
          while @timers
            interval = @timers.wait_interval
            readable, writable = IO.select([@self_read], nil, nil, interval)
            if readable
              handle_signal readable.first.gets.strip
            else
              @timers.fire
            end
          end
        rescue Interrupt
          @timers.cancel
          exit 0
        end
      end

      def load_rails
        # Adapted from: https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/cli.rb

        require 'rails'
        if ::Rails::VERSION::MAJOR < 4
          require File.expand_path("config/environment.rb")
          ::Rails.application.eager_load!
        else
          # Painful contortions, see 1791 for discussion
          require File.expand_path("config/application.rb")
          ::Rails::Application.initializer "shoryuken-later.eager_load" do
            ::Rails.application.config.eager_load = true
          end
          require File.expand_path("config/environment.rb")
        end

        logger.info "Rails environment loaded"
      end

      def daemonize
        return unless Shoryuken::Later.options[:daemon]

        raise ArgumentError, "You really should set a logfile if you're going to daemonize" unless Shoryuken::Later.options[:logfile]

        files_to_reopen = []
        ObjectSpace.each_object(File) do |file|
          files_to_reopen << file unless file.closed?
        end

        Process.daemon(true, true)

        files_to_reopen.each do |file|
          begin
            file.reopen file.path, "a+"
            file.sync = true
          rescue ::Exception
          end
        end

        [$stdout, $stderr].each do |io|
          File.open(Shoryuken::Later.options[:logfile], 'ab') do |f|
            io.reopen(f)
          end
          io.sync = true
        end
        $stdin.reopen('/dev/null')

        initialize_logger
      end

      def write_pid
        if path = Shoryuken::Later.options[:later][:pidfile]
          File.open(path, 'w') do |f|
            f.puts Process.pid
          end
        end
      end

      def parse_options(argv)
        opts = {later: {}}

        @parser = OptionParser.new do |o|
          o.on '-d', '--daemon', 'Daemonize process' do |arg|
            opts[:daemon] = arg
          end

          o.on '-t', '--table TABLE...', 'Table to process' do
            Shoryuken::Later.tables << args
          end

          o.on '-r', '--require [PATH|DIR]', 'Location of the worker' do |arg|
            opts[:require] = arg
          end

          o.on '-C', '--config PATH', 'Path to YAML config file' do |arg|
            opts[:config_file] = arg
          end

          o.on '-R', '--rails', 'Load Rails' do |arg|
            opts[:rails] = arg
          end

          o.on '-L', '--logfile PATH', 'Path to writable logfile' do |arg|
            opts[:logfile] = arg
          end

          o.on '-P', '--pidfile PATH', 'Path to pidfile' do |arg|
            opts[:later][:pidfile] = arg
          end

          o.on '-v', '--verbose', 'Print more verbose output' do |arg|
            opts[:verbose] = arg
          end

          o.on '-V', '--version', 'Print version and exit' do
            puts "Shoryuken::Later #{Shoryuken::Later::VERSION}"
            exit 0
          end
        end

        @parser.banner = 'shoryuken-later [options]'
        @parser.on_tail '-h', '--help', 'Show help' do
          logger.info @parser
          exit 1
        end
        @parser.parse!(argv)
        opts
      end

      def handle_signal(sig)
        logger.info "Got #{sig} signal"

        case sig
        when 'USR1'
          logger.info "Received USR1, will soft shutdown down"
          @timers.cancel
          @timers = nil
        else
          logger.info "Received #{sig}, will shutdown down"
          raise Interrupt
        end
      end

      def setup_options(args)
        options = parse_options(args)

        # yield parsed options in case we need to do more setup before configuration is parsed
        yield(options) if block_given?

        config = options[:config_file] ? parse_config(options[:config_file]).deep_symbolize_keys : {}

        Shoryuken::Later.options[:later].merge!(config.delete(:later) || {})
        Shoryuken::Later.options.merge!(config)

        Shoryuken::Later.options[:later].merge!(options.delete(:later) || {})
        Shoryuken::Later.options.merge!(options)

        # Tables from command line options take precedence...
        unless Shoryuken::Later.tables.any?
          tables = Shoryuken::Later.options[:later][:tables]

          # Use the default table if none were specified in the config file.
          tables << Shoryuken::Later.default_table if tables.empty?

          Shoryuken::Later.tables.replace(tables)
        end
      end

      def parse_config(config_file)
        if File.exist?(config_file)
          YAML.load(ERB.new(IO.read(config_file)).result)
        else
          raise ArgumentError, "Config file #{config_file} does not exist"
        end
      end

      def initialize_logger
        Shoryuken::Logging.initialize_logger(Shoryuken::Later.options[:logfile]) if Shoryuken::Later.options[:logfile]

        Shoryuken::Later.logger.level = Logger::DEBUG if Shoryuken::Later.options[:verbose]
      end

      def validate!
        raise ArgumentError, 'No tables given to poll' if Shoryuken::Later.tables.empty?

        if Shoryuken::Later.options[:aws][:access_key_id].nil? && Shoryuken::Later.options[:aws][:secret_access_key].nil?
          if ENV['AWS_ACCESS_KEY_ID'].nil? && ENV['AWS_SECRET_ACCESS_KEY'].nil?
            raise ArgumentError, 'No AWS credentials supplied'
          end
        end

        initialize_aws

        Shoryuken::Later.tables.uniq.each do |table|
          unless Shoryuken::Later::Client.new(table).table_exist?
            raise ArgumentError, "Table '#{table}' does not exist"
          end
        end
      end

      def initialize_aws
        # aws-sdk tries to load the credentials from the ENV variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
        # when not explicit supplied
        return if Shoryuken::Later.options[:aws].empty?

        shoryuken_keys = %i[
          account_id
          sns_endpoint
          sqs_endpoint
          receive_message
        ]

        aws_options = Shoryuken::Later.options[:aws].reject do |k, _|
          shoryuken_keys.include?(k)
        end

        credentials = Aws::Credentials.new(
          aws_options.delete(:access_key_id),
          aws_options.delete(:secret_access_key)
        )

        Aws.config = aws_options.merge(credentials: credentials)
      end

      def require_workers
        require Shoryuken::Later.options[:require] if Shoryuken::Later.options[:require]
      end
    end
  end
end
