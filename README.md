# shoryuken-later

A scheduling plugin for [Shoryuken](https://github.com/phstc/shoryuken) that uses [Dynamo DB](https://aws.amazon.com/dynamodb/)
to schedule messages arbitrarily far into the future.

## Features

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
# This key is used by both Shoryuken and Shoryuken::Later
aws:
  access_key_id:      ...       # or <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key:  ...       # or <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region:             us-east-1 # or <%= ENV['AWS_REGION'] %>
  
# This key is only used by Shoryuken::Later
later:
  delay: 5 * 60   # How frequently to poll the schedule table, in seconds.
  tables:
    - table1
    
# These keys are used by both Shoryuken and Shoryuken::Later
logfile: some/path/to/file.log
pidfile: some/path/to/file.pid

# These keys are only used by Shoryuken
concurrency: 3
delay: 0
queues:
  - [queue1, 1]
  - [queue2, 2]
```