require 'spec_helper'

describe Shoryuken::Later::Client do
  let(:ddb)              { double 'DynamoDB' }
  let(:table_collection) { double 'Table Collection' }
  let(:ddb_table)        { double 'DynamoDb Table' }
  let(:ddb_items)        { double 'Table Items' }
  let(:table)            { 'shoryuken_later' }

  before do
    allow(described_class).to receive(:ddb).and_return(ddb)
    allow(ddb).to receive(:tables).and_return(table_collection)
    allow(table_collection).to receive(:[]).and_return(ddb_table)
    allow(ddb_table).to receive(:items).and_return(ddb_items)
    allow(ddb_table).to receive(:hash_key=)
  end

  describe '.tables' do
    it 'memoizes tables and sets the hash_key' do
      expect(table_collection).to receive(:[]).once.with(table).and_return(ddb_table)
      expect(ddb_table).to receive(:hash_key=).once.with([:id, :string])

      expect(described_class.tables(table)).to eq(ddb_table)
      expect(described_class.tables(table)).to eq(ddb_table)
    end
  end
  
  describe '.put_item' do
    it 'creates an item with a supplied ID' do
      expect(ddb_items).to receive(:create).with({'id' => 'fubar'}, {unless_exists: 'id'})
        
      described_class.put_item(table,'id' => 'fubar')
    end
    
    it 'creates an item with a auto-generated ID' do
      expect(SecureRandom).to receive(:uuid).once.and_return('fubar')
      expect(ddb_items).to receive(:create).with({'id' => 'fubar', 'perform_at' => 1234}, {unless_exists: 'id'})
        
      described_class.put_item(table,'perform_at' => 1234)
    end
  end
end
