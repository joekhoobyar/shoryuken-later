require 'securerandom'

module Shoryuken
  module Later
    class Client
      def initialize(table_name)
        @table_name = table_name
      end

      def batch
        items = ddb.scan(
          table_name: @table_name,
          limit: 100,
          scan_filter:
            { perform_at:
                {
                  attribute_value_list: [Time.now.to_i],
                  comparison_operator: 'LT'
                }
            }
        ).items
        items.present? ? items : nil
      end

      def create(item)
        item['id'] = SecureRandom.uuid

        ddb.put_item(
          table_name: @table_name,
          item: item,
          expected: { id: { exists: false }}
        )
      end

      def delete(item)
        ddb.delete_item(
          table_name: @table_name,
          key: { id: item['id'], perform_at: item['perform_at'].to_i },
          expected: {
            id: { value: item['id'], exists: true },
            perform_at: { value: item['perform_at'].to_i, exists: true }
          }
        )
      end

      def table_exist?
        ddb.describe_table(table_name: @table_name)
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        false
      end

      private

      def ddb
        opts = {}

        if ENV['LOCALSTACK']
          opts[:endpoint] = 'http://localhost:4566'
          opts[:credentials] = Aws::Credentials.new('fake', 'fake')
        end

        @ddb ||= Aws::DynamoDB::Client.new(opts)
      end
    end
  end
end
