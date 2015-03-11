require 'bundler/setup'
Bundler.setup

require 'shoryuken-later'
require 'json'

options_file = File.join(File.expand_path('../..', __FILE__), 'shoryuken.yml')

$options = {}

if File.exists? options_file
  $options = YAML.load(File.read(options_file)).deep_symbolize_keys

  AWS.config $options[:aws]
end

Shoryuken.logger.level = Logger::UNKNOWN

# For Ruby 1.9
module Kernel
  def Hash(arg)
    case arg
    when NilClass
      {}
    when Hash
      arg
    when Array
      Hash[*arg]
    else
      raise TypeError
    end
  end unless method_defined? :Hash
end

# For Ruby 1.9
class Hash
  def to_h
    self
  end unless method_defined? :to_h
end

class TestWorker
  include Shoryuken::Worker

  shoryuken_options queue: 'shoryuken_later', schedule_table: 'shoryuken_later'

  def perform(sqs_msg, body); end
end

RSpec.configure do |config|
  config.before do
    Shoryuken::Later::Client.class_variable_set :@@tables, {}

    Shoryuken::Later.options.clear
    Shoryuken::Later.options.merge!($options)

    Shoryuken::Later.tables.replace(['shoryuken_later'])

    Shoryuken::Later.options[:later][:delay] = 60
    Shoryuken::Later.options[:later][:tables] = ['shoryuken_later']
    Shoryuken::Later.options[:timeout]       = 1

    Shoryuken::Later.options[:aws] = {}

    TestWorker.get_shoryuken_options.clear
    TestWorker.get_shoryuken_options['queue'] = 'shoryuken_later'
    TestWorker.get_shoryuken_options['schedule_table'] = 'shoryuken_later'

    Shoryuken.worker_registry.clear
    Shoryuken.register_worker('shoryuken_later', TestWorker)
  end
end
