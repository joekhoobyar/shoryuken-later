require 'securerandom'

module Shoryuken
  module Later
    class Client
      @@tables = {}
        
      class << self
        def tables(table)
          @@tables[table.to_s] ||= ddb.tables[table].tap do |tbl|
            tbl.hash_key = [:id, :string]
            tbl.range_key = [:perform_at, :number]
          end
        end
        
        def put_item(table, attributes, options={unless_exists: 'id'})
          attributes['id'] ||= SecureRandom.uuid
          tables(table).items.create(attributes, options)
        end
        
        def ddb
          @ddb ||= AWS::DynamoDB.new
        end
      end
    end
  end
end
