require 'spec_helper'

describe Shoryuken::Later::Client do
  let(:ddb)               { double 'DynamoDB' }
  let(:table_description) { double 'Table Description' }
  let(:table)             { 'shoryuken_later' }

  before do
    allow(described_class).to receive(:ddb).and_return(ddb)
    allow(ddb).to receive(:describe_table).and_return(table_description)
  end

  describe '.tables' do
    it 'memoizes tables' do
      expect(ddb).to receive(:describe_table).once.with(table_name: table).and_return(table_description)

      expect(described_class.tables(table)).to eq(table_description)
      expect(described_class.tables(table)).to eq(table_description)
    end
  end
  
  describe '.create_item' do
    it 'creates an item with a supplied ID' do
      expect(ddb).to receive(:put_item).with(table_name: table, item: {'id' => 'fubar'}, expected: {id: {exists: false}})
        
      described_class.create_item(table,'id' => 'fubar')
    end
    
    it 'creates an item with a auto-generated ID' do
      expect(SecureRandom).to receive(:uuid).once.and_return('fubar')
      expect(ddb).to receive(:put_item).with(table_name: table, item: {'id' => 'fubar', 'perform_at' => 1234}, expected: {id: {exists: false}})
        
      described_class.create_item(table,'perform_at' => 1234)
    end
  end
end
