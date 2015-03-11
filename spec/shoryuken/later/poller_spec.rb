require 'spec_helper'
require 'shoryuken/later/poller'

describe Shoryuken::Later::Poller do
  let(:ddb_table) { double 'DynamoDb Table' }
  let(:ddb_items) { double 'Table Items' }
  let(:table)     { 'shoryuken_later' }
  
  let(:body)      { {'foo' => 'bar'} }  
  let(:json)      { JSON.dump(body: body, options: {}) }
    
  let(:ddb_item)  do
    double AWS::DynamoDB::Item, delete: nil,
      attributes: {'id' => 'fubar', 'perform_at' => Time.now + 60, 'shoryuken_args' => json, 'shoryuken_class' => 'TestWorker'}
  end

  before do
    allow(Shoryuken::Later::Client).to receive(:tables).with(table).and_return(ddb_table)
  end

  subject do
    described_class.new(table)
  end
  
  describe '#poll' do
    it 'pulls items from #next_item, and processes with #process_item' do
      items = [ddb_item]
      expect_any_instance_of(described_class).to receive(:next_item).twice { items.pop }
      expect_any_instance_of(described_class).to receive(:process_item).once.with(ddb_item)

      subject.poll
    end
    
    it 'does not call #process_item when there are no items' do
      items = []
      expect_any_instance_of(described_class).to receive(:next_item).once { items.pop }
      expect_any_instance_of(described_class).not_to receive(:process_item)

      subject.poll
    end
  end
  
  describe '#process_item' do
    it 'enqueues a message if the item could be deleted' do
      expect(TestWorker).to receive(:perform_in).once do |time,body,options|
        expect(time   ).to be > Time.now
        expect(body   ).to eq(body)
        expect(options).to be_empty
      end
      
      subject.send(:process_item, ddb_item)
    end
    
    it 'does not enqueue a message if the item could not be deleted' do
      expect(TestWorker).not_to receive(:perform_in)
      allow(ddb_item).to receive(:delete) { raise AWS::DynamoDB::Errors::ConditionalCheckFailedException }
      
      subject.send(:process_item, ddb_item)
    end
  end
end
