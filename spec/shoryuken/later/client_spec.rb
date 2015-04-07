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
    it 'creates an item with unique hash and range key' do
      expect(SecureRandom).to receive(:uuid).once.and_return('fubar')
      expect(Random).to receive(:rand).once.and_return(5678)
      expect(ddb).to receive(:put_item).with(table_name: table, item: {'id' => 'fubar', 'perform_at' => '1234.5678', 'scheduler' => 'shoryuken-later'})

      described_class.create_item(table,'perform_at' => 1234)
    end
  end
end
