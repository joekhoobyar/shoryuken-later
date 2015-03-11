# shoryuken-later

A scheduling plugin for [Shoryuken](https://github.com/phstc/shoryuken) that uses [Dynamo DB](https://aws.amazon.com/dynamodb/)
to delay messages arbitrarily far into the future.

## Features

### Supports distributed architectures

An SQS message is *only* queued if a _conditional_ delete of the DDB item is successful. This eliminates any potential race condition, so if more than one `shoryuken-later` process is polling the same schedule table then no redundant SQS messages will be queued.

NOTE: You shouldn't really _need_ to run more than one process, but if you do it will be safe.

### One or more schedule tables

Supports polling one or more DynamoDB tables for messages.

```yaml
later:
  tables:
    - default_schedule
    - other_schedule
```

### Namespaced configuration

You can use the same configuration file for both `Shoryuken` and `Shoryuken::Later`, because the new configuration options are namespaced.

```yaml
# These keys are used by both Shoryuken and Shoryuken::Later
aws:
  access_key_id:      ...       # or <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key:  ...       # or <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region:             us-east-1 # or <%= ENV['AWS_REGION'] %>
logfile: some/path/to/file.log
  
# This key is only used by Shoryuken::Later
later:
  delay: 5 * 60   # How frequently to poll the schedule table, in seconds.
  pidfile: some/path/to/file.pid
  tables:
    - table1

# These keys are only used by Shoryuken
concurrency: 3
delay: 0
queues:
  - [queue1, 1]
  - [queue2, 2]
```

## Usage

### Integration with ActiveJob

A custom ActiveJob adapter can used to support delaying messages arbitrarily far into the future.

```ruby
# config/application.rb
config.active_job.queue_adapter = :shoryuken_later
```

When you use the `:shoryuken_later` queue adapter, jobs to be performed farther than 15 minutes into the future (by setting the `wait` or `wait_until` ActiveJob options), will be inserted into the *default* schedule table.  You can set the default schedule table in an initializer.

```ruby
# config/initializers/shoryuken_later.rb
Shoryuken::Later.default_table = "#{Rails.env}_myapp_later"
```


### Integration with Shoryuken::Worker

A new method named `perform_later` is added to `Shoryuken::Worker` allowing messages to be delayed arbitrarily far into the future. If the delay is 15 minutes or less, then the message is enqueued into the specified SQS `:queue` as usual.  Otherwise, the message is inserted into the specified DynamoDB `:schedule_table`.

```ruby
 require 'shoryuken-later'

 class MyWorker
   include Shoryuken::Worker
  
   shoryuken_options queue: 'default', schedule_table: 'default_schedule'
 end

 # Schedules a message to be processed 30 minutes from now.
 MyWorker.perform_later(Time.now + 30 * 60, 'Foobar')
```


## Requirements

Ruby 2.0 or greater. Ruby 1.9 is no longer supported.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shoryuken-later'
```

Or to get the latest updates:

```ruby
gem 'shoryuken-later', github: 'joekhoobyar/shoryuken-later', branch: 'master'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shoryuken-later
    
## Documentation

Learn about using Shoryuken at the [Shoryuken Wiki](https://github.com/phstc/shoryuken/wiki).

## Credits

[Pablo Cantero](https://github.com/phstc), creator of [Shoryuken](https://github.com/phstc/shoryuken), and [everybody who contributed to it](https://github.com/phstc/shoryuken/graphs/contributors).  I borrowed a lot of code from Shoryuken itself as a shortcut to making this gem.

## Contributing

1. Fork it ( https://github.com/joekhoobyar/shoryuken-later/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
