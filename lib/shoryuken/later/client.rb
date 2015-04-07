require 'securerandom'

module Shoryuken
  module Later
    class Client
      @@tables = {}

      class << self
        def tables(table)
          @@tables[table] ||= ddb.describe_table(table_name: table)
        end

        def items(table)
          threshold = (Time.now + Shoryuken::Later::MAX_QUEUE_DELAY).to_i
          params = {
            table_name: table,
            key_conditions: {
              scheduler: {
                attribute_value_list: [ "shoryuken-later" ],
                comparison_operator: "EQ",
              },
              perform_at: {
                attribute_value_list: [ threshold ],
                comparison_operator: "LT",
              },
            }
          }

          ddb.query(params).inject([]) { |m, r| m += r; m }
        end

        def create_item(table, item)
          # Items are intended for tables with hash+range primary keys. The
          # `scheduler` hash key is essentially meaningless, it but a hash key
          # is required. By having a meaningful range key that can also provide
          # uniqueness, querying for pending items is fairly efficient.

          item['scheduler'] = 'shoryuken-later'

          # Add a random fraction to maintain unique range keys for jobs with
          # a single second
          # (DynamoDB take Number values as Strings to avoid precision issues)
          item['perform_at'] = "#{item['perform_at']}.#{Random.rand(2 ** 64)}"

          # Mostly for record keeping
          item['id'] = SecureRandom.uuid

          ddb.put_item({
            table_name: table,
            item: item,
            # condition_expression: "" # TODO `expected` is deprecated
            # expected: { perform_at: { exists: false } }
          })
        end

        def delete_item(table, item)
          ddb.delete_item({
            table_name: table,
            key: {
              scheduler: item['scheduler'],
              perform_at: item['perform_at']
            },
            # expected: { perform_at: { value: item['perform_at'], exists: true } } # TODO Deprecated
          })
        end

        def ddb
          @ddb ||= Aws::DynamoDB::Client.new
        end
      end
    end
  end
end
