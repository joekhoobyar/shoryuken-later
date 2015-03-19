require 'bundler/gem_tasks'

$stdout.sync = true

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  # no rspec available
end

desc 'Open Shoryuken::Later pry console'
task :console do
  require 'pry'
  require 'shoryuken-later'

  config_file = File.join File.expand_path('..', __FILE__), 'shoryuken.yml'

  if File.exist? config_file
    config = YAML.load File.read(config_file)
    Aws.config = config['aws']
  end

  ARGV.clear
  Pry.start
end
