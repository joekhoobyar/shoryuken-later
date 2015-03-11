require 'spec_helper'
require 'shoryuken/later/poller'

describe Shoryuken::Later::Poller do
  let(:ddb)       { double 'DynamoDB' }
  let(:body)      { {'foo' => 'bar'} }  
  let(:json)      { JSON.dump(body: body, options: {}) }
  let(:table)     { 'shoryuken_later' }
    
  let(:ddb_item)  do
    {'id' => 'fubar', 'perform_at' => Time.now + 60, 'shoryuken_args' => json, 'shoryuken_class' => 'TestWorker'}
  end

  before do
    allow(Shoryuken::Later::Client).to receive(:ddb).and_return(ddb)
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
      allow(Shoryuken::Later::Client).to receive(:delete_item).with(table, ddb_item)
      
      expect(TestWorker).to receive(:perform_in).once do |time,body,options|
        expect(time   ).to be > Time.now
        expect(body   ).to eq(body)
        expect(options).to be_empty
      end
      
      subject.send(:process_item, ddb_item)
    end
    
    it 'does not enqueue a message if the item could not be deleted' do
      expect(TestWorker).not_to receive(:perform_in)
      expect(Shoryuken::Later::Client).to receive(:delete_item).with(table, ddb_item){ raise AWS::DynamoDB::Errors::ConditionalCheckFailedException }
      
      subject.send(:process_item, ddb_item)
    end
  end
end
